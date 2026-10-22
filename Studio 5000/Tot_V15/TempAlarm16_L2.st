// ===============================================================
// AOI 名称: TempAlarm16_L2 (16路温度测点二级超温报警批量处理)
// 版本: 2.0
// 编程语言: Structured Text (ST)
// 适用平台: Studio 5000 (ControlLogix/CompactLogix)
// ===============================================================
// 功能概述:
// 1. 对全部 16 路温度测点进行批量二级超温监视:
//      一级报警(提示/高报) -> 非强制提示: HMI 顶部醒目横幅 + 测点卡片高亮,
//                             不弹窗不鸣笛, 提醒值班人员关注该测点变化趋势;
//      二级报警(警告/高报) -> 强制介入提示: HMI 弹窗 + 声响提醒,
//                             且"未确认"状态被锁存, 值班人员必须按下确认键
//                             (Ack_Alm2) 才能解除弹窗与声响;
// 2. 所有测点配置由调用方通过 Input 参数 In_Cfg 直接传入(阈值/回差/延时
//    / 使能/测点标识), 外部程序可按通道单独修改, 也可数组整体 MOV;
// 3. 全部 16 路共用一个 FOR 循环, 无任何重复逻辑;
// 4. 报警通道统一具备回差过滤 + 秒时基防抖;
// 5. 环形缓冲保存最近 32 条事件(测点标识快照 + 类型 + PV + 时标);
// 6. 若 Input 参数某通道整定值为 0(未配置), AOI 自动写入默认值作为
//    "生效配置", 存于 HMI_CMD 内(可被外部程序实时读取)。
// ===============================================================
// 测点通道分配表(下标 0..15):
//   组1 电机定子温度(6点): 0=定子U1  1=定子V1  2=定子W1
//                          3=定子U2  4=定子V2  5=定子W2
//   组2 电机轴承温度(4点): 6=驱动端轴承  7=非驱动端轴承
//                          8=轴承3        9=轴承4
//   组3 渣浆泵轴承温度(4点): 10=泵轴承1  11=泵轴承2
//                            12=泵轴承3  13=泵轴承4
//   组4 减速机油温(2点):   14=油温1     15=油温2
// ===============================================================
// 默认整定值(Input 参数对应通道 SP2<=0 时自动作为生效值):
//   组1 定子:      SP1=130  SP2=145  Hys=3  Dly1=3s  Dly2=2s
//   组2 电机轴承:  SP1=85   SP2=95   Hys=3  Dly1=3s  Dly2=2s
//   组3 泵轴承:    SP1=80   SP2=90   Hys=3  Dly1=3s  Dly2=2s
//   组4 减速机油:  SP1=75   SP2=85   Hys=3  Dly1=3s  Dly2=2s
// 默认测点标识名:
//   StatorU1,V1,W1,U2,V2,W2 / MtrBrgDE,NDE,3,4 / PumpBrg1..4 / GearOil1,2
// ===============================================================
// 报警动作逻辑(单通道, 一级/二级结构相同):
//        产生: PV >= SP 且连续保持 Dly 秒  -> Alm = 1 (记录事件)
//        解除: PV <  SP - Hys (立即)       -> Alm = 0 (记录事件)
// ===============================================================
// 变量约定:
//   输入  : Hour / Minute / Second (DINT) -- 事件记录时标; Second 同时作为
//                                              防抖秒节拍(Tick := Second <> Prev_Second)
//           PV(REAL[16])                    16 路实时温度
//           In_Cfg(TempAlarm16_L2_Cfg_Type) 全部可配置参数的输入配置块
//                                              (由外部程序/MOV 直接传入)
//   输出  : Out_Warn(BOOL)  任一路一级报警总出口(非强制提示横幅)
//           Out_Trip(BOOL)  任一路二级报警总出口(停机联锁)
//           Out_Horn(BOOL)  声响提醒输出(任一二级报警"未确认"时置位)
//   InOut : HMI_CMD - 运行时状态(报警状态/未确认锁存/防抖计数/边沿记录/
//                     事件记录/生效配置镜像/批量下发命令/权限等级)
//   本地  : Tick(BOOL) 秒节拍 / Prev_Second(DINT) 上一秒
//           i, GS, GE (DINT) / IsFirstScan (BOOL)
//   注意: AOI 的本地变量只能是原子标量, 不支持数组,
//         因此防抖计数与边沿状态数组放在 InOut HMI_CMD 内
//         (Acc1[16] / Acc2[16] / PrevAlm1[16] / PrevAlm2[16])。
//
// ===== 输入配置 UDT 结构 TempAlarm16_L2_Cfg_Type =====
// 成员               类型          说明
//   SP1[16]          REAL          一级报警阈值
//   SP2[16]          REAL          二级报警阈值
//   Hys[16]          REAL          回差值
//   Dly1[16]         DINT          一级延时(秒)
//   Dly2[16]         DINT          二级延时(秒)
//   Enable[16]       BOOL          各通道使能(1=投入 0=退出)
//   Name[16]         STRING        测点标识名(事件记录快照源)
// ===============================================================

// ===============================================================
// 功能段 1: 生效配置计算(Input 参数 vs 默认值)
// ===============================================================
// 判定规则:
//   In_Cfg.SP2[i] > 0.0  -> 使用 Input 参数值(用户已配置);
//   否则                 -> 使用按所属组确定的默认值;
// 结果存入 HMI_CMD.Eff_* 数组, 判定逻辑统一引用 Eff_*,
// 这样既支持外部程序直接 Input 接线修改, 也支持首次上电零值自动填充。
// 批量下发命令(功能段 2)会同时写入 Input 参数和 Eff_*,
// 两种改法等价, 外部程序可任选其一。

FOR i := 0 TO 15 DO
    IF In_Cfg.SP2[i] > 0.0 THEN
        // 外部已配置: 直接同步到生效配置(使外部 MOV 立即可见)
        HMI_CMD.Eff_SP1[i]    := In_Cfg.SP1[i];
        HMI_CMD.Eff_SP2[i]    := In_Cfg.SP2[i];
        HMI_CMD.Eff_Hys[i]    := In_Cfg.Hys[i];
        HMI_CMD.Eff_Dly1[i]   := In_Cfg.Dly1[i];
        HMI_CMD.Eff_Dly2[i]   := In_Cfg.Dly2[i];
        HMI_CMD.Eff_Enable[i] := In_Cfg.Enable[i];
        HMI_CMD.Eff_Name[i]   := In_Cfg.Name[i];
    ELSE
        // 外部未配置: 写入生效默认值(供判定逻辑使用)
        IF i <= 5 THEN
            HMI_CMD.Eff_SP1[i] := 130.0; HMI_CMD.Eff_SP2[i] := 145.0;
        ELSIF i <= 9 THEN
            HMI_CMD.Eff_SP1[i] := 85.0;  HMI_CMD.Eff_SP2[i] := 95.0;
        ELSIF i <= 13 THEN
            HMI_CMD.Eff_SP1[i] := 80.0;  HMI_CMD.Eff_SP2[i] := 90.0;
        ELSE
            HMI_CMD.Eff_SP1[i] := 75.0;  HMI_CMD.Eff_SP2[i] := 85.0;
        END_IF;
        HMI_CMD.Eff_Hys[i]    := 3.0;
        HMI_CMD.Eff_Dly1[i]   := 3;
        HMI_CMD.Eff_Dly2[i]   := 2;
        HMI_CMD.Eff_Enable[i] := 1;

        // 默认测点标识名
        CASE i OF
            0:  HMI_CMD.Eff_Name[0]  := 'StatorU1';
            1:  HMI_CMD.Eff_Name[1]  := 'StatorV1';
            2:  HMI_CMD.Eff_Name[2]  := 'StatorW1';
            3:  HMI_CMD.Eff_Name[3]  := 'StatorU2';
            4:  HMI_CMD.Eff_Name[4]  := 'StatorV2';
            5:  HMI_CMD.Eff_Name[5]  := 'StatorW2';
            6:  HMI_CMD.Eff_Name[6]  := 'MtrBrgDE';
            7:  HMI_CMD.Eff_Name[7]  := 'MtrBrgNDE';
            8:  HMI_CMD.Eff_Name[8]  := 'MtrBrg3';
            9:  HMI_CMD.Eff_Name[9]  := 'MtrBrg4';
            10: HMI_CMD.Eff_Name[10] := 'PumpBrg1';
            11: HMI_CMD.Eff_Name[11] := 'PumpBrg2';
            12: HMI_CMD.Eff_Name[12] := 'PumpBrg3';
            13: HMI_CMD.Eff_Name[13] := 'PumpBrg4';
            14: HMI_CMD.Eff_Name[14] := 'GearOil1';
            15: HMI_CMD.Eff_Name[15] := 'GearOil2';
        END_CASE;
    END_IF;
END_FOR;

// ===============================================================
// 功能段 2: 批量参数下发(InOut 命令 + 权限校验)
// ===============================================================
// 除了外部程序直接 MOV In_Cfg, 也支持 HMI 统一下发:
//   HMI_CMD.Apply_Batch 置位后, 按 B_Group 指定的通道范围,
//   将 B_SP1/B_SP2/B_Hys/B_Dly1/B_Dly2 写入 In_Cfg(Input) 与
//   HMI_CMD.Eff_*, 并记录类型 5/6 事件。
// 安全规则: User_Level >= 2 且 SP2 > SP1 且 Hys >= 0。
// 外部程序绕过权限直接 MOV In_Cfg 也是允许的——
// 权限校验只针对 Apply_Batch 这条批量命令, 直接改 Input 不审计。
IF HMI_CMD.Apply_Batch THEN
    IF HMI_CMD.User_Level >= 2 THEN
        IF (HMI_CMD.B_SP2 > HMI_CMD.B_SP1) AND (HMI_CMD.B_Hys >= 0.0) THEN
            CASE HMI_CMD.B_Group OF
                1: GS := 0;  GE := 5;
                2: GS := 6;  GE := 9;
                3: GS := 10; GE := 13;
                4: GS := 14; GE := 15;
                ELSE GS := 0; GE := 15;
            END_CASE;
            FOR i := GS TO GE DO
                In_Cfg.SP1[i] := HMI_CMD.B_SP1;
                In_Cfg.SP2[i] := HMI_CMD.B_SP2;
                In_Cfg.Hys[i] := HMI_CMD.B_Hys;
                In_Cfg.Dly1[i] := HMI_CMD.B_Dly1;
                In_Cfg.Dly2[i] := HMI_CMD.B_Dly2;
                // 功能段 1 下一次扫描会自动同步 Eff_*
            END_FOR;
            HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]     := HMI_CMD.B_Group;
            HMI_CMD.Evt_ChName[HMI_CMD.Evt_Head] := 'BATCH';
            HMI_CMD.Evt_Type[HMI_CMD.Evt_Head] := 5;
            HMI_CMD.Evt_PV[HMI_CMD.Evt_Head]   := 0.0;
            HMI_CMD.Evt_H[HMI_CMD.Evt_Head]    := Hour;
            HMI_CMD.Evt_M[HMI_CMD.Evt_Head]    := Minute;
            HMI_CMD.Evt_S[HMI_CMD.Evt_Head]    := Second;
            HMI_CMD.Evt_Head := (HMI_CMD.Evt_Head + 1) MOD 32;
        END_IF;
    ELSE
        HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]     := HMI_CMD.B_Group;
        HMI_CMD.Evt_ChName[HMI_CMD.Evt_Head] := 'BATCH';
        HMI_CMD.Evt_Type[HMI_CMD.Evt_Head] := 6;
        HMI_CMD.Evt_PV[HMI_CMD.Evt_Head]   := 0.0;
        HMI_CMD.Evt_H[HMI_CMD.Evt_Head]    := Hour;
        HMI_CMD.Evt_M[HMI_CMD.Evt_Head]    := Minute;
        HMI_CMD.Evt_S[HMI_CMD.Evt_Head]    := Second;
        HMI_CMD.Evt_Head := (HMI_CMD.Evt_Head + 1) MOD 32;
    END_IF;
    HMI_CMD.Apply_Batch := 0;
END_IF;

// ===============================================================
// 功能段 3: 16 路报警核心批量处理(FOR 循环统一逻辑)
// ===============================================================
// 判定逻辑统一引用 HMI_CMD.Eff_* 数组(由功能段 1 从上电零值/
// Input 参数中合成), 对调用方透明, 外部改 Input 立即生效。

// 秒节拍: 仅在 Second 发生变化的那个扫描周期为 1
Tick := (Second <> Prev_Second);
Prev_Second := Second;

FOR i := 0 TO 15 DO

    // ---------- 通道禁用时: 强制安全状态 ----------
    IF NOT HMI_CMD.Eff_Enable[i] THEN
        HMI_CMD.Sta_Alm1[i] := 0;
        HMI_CMD.Sta_Alm2[i] := 0;
        HMI_CMD.Acc1[i] := 0;
        HMI_CMD.Acc2[i] := 0;

    ELSE
        // ---------- 一级报警(提示/高报) ----------
        IF PV[i] < HMI_CMD.Eff_SP1[i] THEN
            HMI_CMD.Acc1[i] := 0;
        END_IF;
        IF Tick AND (PV[i] >= HMI_CMD.Eff_SP1[i]) THEN
            HMI_CMD.Acc1[i] := HMI_CMD.Acc1[i] + 1;
        END_IF;
        IF PV[i] < (HMI_CMD.Eff_SP1[i] - HMI_CMD.Eff_Hys[i]) THEN
            HMI_CMD.Sta_Alm1[i] := 0;
            HMI_CMD.Acc1[i] := 0;
        ELSIF HMI_CMD.Acc1[i] >= HMI_CMD.Eff_Dly1[i] THEN
            HMI_CMD.Sta_Alm1[i] := 1;
        END_IF;

        // ---------- 二级报警(警告/高报) ----------
        IF PV[i] < HMI_CMD.Eff_SP2[i] THEN
            HMI_CMD.Acc2[i] := 0;
        END_IF;
        IF Tick AND (PV[i] >= HMI_CMD.Eff_SP2[i]) THEN
            HMI_CMD.Acc2[i] := HMI_CMD.Acc2[i] + 1;
        END_IF;
        IF PV[i] < (HMI_CMD.Eff_SP2[i] - HMI_CMD.Eff_Hys[i]) THEN
            HMI_CMD.Sta_Alm2[i] := 0;
            HMI_CMD.Acc2[i] := 0;
        ELSIF HMI_CMD.Acc2[i] >= HMI_CMD.Eff_Dly2[i] THEN
            HMI_CMD.Sta_Alm2[i] := 1;
        END_IF;
    END_IF;

    // ---------- 事件记录: 边沿检测(类型1..4) ----------
    // 类型1=一级产生 2=一级解除 3=二级产生 4=二级解除
    // 测点标识名取自 Eff_Name(已是生效配置, 含默认值兜底)
    IF HMI_CMD.Sta_Alm1[i] AND NOT HMI_CMD.PrevAlm1[i] THEN
        HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]     := i;
        HMI_CMD.Evt_ChName[HMI_CMD.Evt_Head] := HMI_CMD.Eff_Name[i];
        HMI_CMD.Evt_Type[HMI_CMD.Evt_Head] := 1;
        HMI_CMD.Evt_PV[HMI_CMD.Evt_Head]   := PV[i];
        HMI_CMD.Evt_H[HMI_CMD.Evt_Head]    := Hour;
        HMI_CMD.Evt_M[HMI_CMD.Evt_Head]    := Minute;
        HMI_CMD.Evt_S[HMI_CMD.Evt_Head]    := Second;
        HMI_CMD.Evt_Head := (HMI_CMD.Evt_Head + 1) MOD 32;
    ELSIF (NOT HMI_CMD.Sta_Alm1[i]) AND HMI_CMD.PrevAlm1[i] THEN
        HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]     := i;
        HMI_CMD.Evt_ChName[HMI_CMD.Evt_Head] := HMI_CMD.Eff_Name[i];
        HMI_CMD.Evt_Type[HMI_CMD.Evt_Head] := 2;
        HMI_CMD.Evt_PV[HMI_CMD.Evt_Head]   := PV[i];
        HMI_CMD.Evt_H[HMI_CMD.Evt_Head]    := Hour;
        HMI_CMD.Evt_M[HMI_CMD.Evt_Head]    := Minute;
        HMI_CMD.Evt_S[HMI_CMD.Evt_Head]    := Second;
        HMI_CMD.Evt_Head := (HMI_CMD.Evt_Head + 1) MOD 32;
    END_IF;

    IF HMI_CMD.Sta_Alm2[i] AND NOT HMI_CMD.PrevAlm2[i] THEN
        // 二级报警: 强制介入级, 置位同时锁存"未确认"标志,
        // 必须由值班人员按 Ack_Alm2 才能解除弹窗/声响
        HMI_CMD.Alm2_UnAck[i] := 1;
        HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]     := i;
        HMI_CMD.Evt_ChName[HMI_CMD.Evt_Head] := HMI_CMD.Eff_Name[i];
        HMI_CMD.Evt_Type[HMI_CMD.Evt_Head] := 3;
        HMI_CMD.Evt_PV[HMI_CMD.Evt_Head]   := PV[i];
        HMI_CMD.Evt_H[HMI_CMD.Evt_Head]    := Hour;
        HMI_CMD.Evt_M[HMI_CMD.Evt_Head]    := Minute;
        HMI_CMD.Evt_S[HMI_CMD.Evt_Head]    := Second;
        HMI_CMD.Evt_Head := (HMI_CMD.Evt_Head + 1) MOD 32;
    ELSIF (NOT HMI_CMD.Sta_Alm2[i]) AND HMI_CMD.PrevAlm2[i] THEN
        HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]     := i;
        HMI_CMD.Evt_ChName[HMI_CMD.Evt_Head] := HMI_CMD.Eff_Name[i];
        HMI_CMD.Evt_Type[HMI_CMD.Evt_Head] := 4;
        HMI_CMD.Evt_PV[HMI_CMD.Evt_Head]   := PV[i];
        HMI_CMD.Evt_H[HMI_CMD.Evt_Head]    := Hour;
        HMI_CMD.Evt_M[HMI_CMD.Evt_Head]    := Minute;
        HMI_CMD.Evt_S[HMI_CMD.Evt_Head]    := Second;
        HMI_CMD.Evt_Head := (HMI_CMD.Evt_Head + 1) MOD 32;
    END_IF;

    HMI_CMD.PrevAlm1[i] := HMI_CMD.Sta_Alm1[i];
    HMI_CMD.PrevAlm2[i] := HMI_CMD.Sta_Alm2[i];
END_FOR;

// ===============================================================
// 功能段 4: 报警汇总与分级提示输出
// ===============================================================
HMI_CMD.Alm1_Count := 0;
HMI_CMD.Alm2_Count := 0;
HMI_CMD.Any_Alm2_UnAck := 0;
FOR i := 0 TO 15 DO
    IF HMI_CMD.Sta_Alm1[i] THEN
        HMI_CMD.Alm1_Count := HMI_CMD.Alm1_Count + 1;
    END_IF;
    IF HMI_CMD.Sta_Alm2[i] THEN
        HMI_CMD.Alm2_Count := HMI_CMD.Alm2_Count + 1;
    END_IF;
    IF HMI_CMD.Alm2_UnAck[i] THEN
        HMI_CMD.Any_Alm2_UnAck := 1;
    END_IF;
END_FOR;

HMI_CMD.Any_Alm1 := (HMI_CMD.Alm1_Count > 0);
HMI_CMD.Any_Alm2 := (HMI_CMD.Alm2_Count > 0);
Out_Warn := HMI_CMD.Any_Alm1;
Out_Trip := HMI_CMD.Any_Alm2;
Out_Horn := HMI_CMD.Any_Alm2_UnAck;

// ===============================================================
// 功能段 5: 二级报警确认(Ack)处理
// ===============================================================
IF HMI_CMD.Ack_Alm2 THEN
    FOR i := 0 TO 15 DO
        HMI_CMD.Alm2_UnAck[i] := 0;
    END_FOR;
    HMI_CMD.Ack_Alm2 := 0;
END_IF;

// ===============================================================
// 功能段 6: 事件记录清空命令
// ===============================================================
IF HMI_CMD.Reset_Log THEN
    FOR i := 0 TO 31 DO
        HMI_CMD.Evt_Ch[i]     := 0;
        HMI_CMD.Evt_ChName[i] := '';
        HMI_CMD.Evt_Type[i] := 0;
        HMI_CMD.Evt_PV[i]   := 0.0;
        HMI_CMD.Evt_H[i]    := 0;
        HMI_CMD.Evt_M[i]    := 0;
        HMI_CMD.Evt_S[i]    := 0;
    END_FOR;
    HMI_CMD.Evt_Head := 0;
    HMI_CMD.Reset_Log := 0;
END_IF;

// ===============================================================
// 功能段 7: 启用状态输出
// ===============================================================
EnableOut := EnableIn;
