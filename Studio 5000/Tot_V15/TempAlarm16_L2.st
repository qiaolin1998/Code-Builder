// ===============================================================
// AOI 名称: TempAlarm16_L2 (16路温度测点二级超温报警批量处理)
// 版本: 1.0
// 编程语言: Structured Text (ST)
// 适用平台: Studio 5000 (ControlLogix/CompactLogix)
// ===============================================================
// 功能概述:
// 1. 对全部 16 路温度测点进行批量二级超温监视:
//      一级报警(预警/高报)   -> 提示值班人员介入处理;
//      二级报警(停机/高高报) -> 驱动停机联锁输出 Out_Trip;
// 2. 所有测点配置与状态均采用数组存储, 核心逻辑用一个 FOR 循环
//    统一处理, 16 路共用同一份代码, 无任何重复逻辑;
// 3. 每路独立配置: 使能 / 一级阈值 / 二级阈值 / 回差 / 一级延时 / 二级延时;
// 4. 全部报警通道统一具备:
//      - 回差过滤: 报警产生阈值 = SP, 解除阈值 = SP - Hys,
//        防止 PV 在阈值附近小幅波动时报警反复抖动;
//      - 延时防抖: 报警条件须连续成立达到设定延时后才真正置位,
//        瞬时尖峰/干扰不会误触发; 解除为立即动作(经回差判定);
// 5. 事件记录: 环形缓冲保存最近 32 条事件(报警产生/解除/参数修改),
//    含通道号、事件类型、当时 PV 与时标, 供 HMI 追溯;
// 6. 批量参数配置: HMI 可按"组"统一下发阈值/回差/延时,
//    写入前校验操作权限等级(User_Level >= 2 才允许修改);
// 7. 掉电保持: 全部配置与状态保存在 HMI_CMD(InOut) 对应的
//    控制器标签中, ControlLogix 标签值掉电保持, 重启后参数不丢失。
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
// 默认整定值(首次上电自动写入, 之后可在 HMI 修改):
//   组1 定子:      SP1=130  SP2=145  Hys=3  Dly1=3s  Dly2=2s
//   组2 电机轴承:  SP1=85   SP2=95   Hys=3  Dly1=3s  Dly2=2s
//   组3 泵轴承:    SP1=80   SP2=90   Hys=3  Dly1=3s  Dly2=2s
//   组4 减速机油:  SP1=75   SP2=85   Hys=3  Dly1=3s  Dly2=2s
// ===============================================================
// 报警动作逻辑(单通道, 一级/二级结构相同):
//        产生: PV >= SP 且连续保持 Dly 秒  -> Alm = 1 (记录事件)
//        解除: PV <  SP - Hys (立即)       -> Alm = 0 (记录事件)
//   SP-Hys ──────┐
//                │ 解除区(回差带内保持原状态)
//   SP    ───────┴── 产生线
// 变量约定:
//   输入  : Hour / Minute / Second (DINT) -- 事件记录时标
//   输出  : Out_Warn(BOOL) 任一路一级报警总出口(预警)
//           Out_Trip(BOOL) 任一路二级报警总出口(停机联锁)
//   InOut : HMI_CMD - 详见 UDT 注释(PV/配置/状态/批量参数/事件记录)
//   本地  : Tmr1/Tmr2 TIMER[16] 每路独立的防抖定时器
//           PrevAlm1/PrevAlm2 BOOL[16] 报警状态边沿检测
//           i, GS, GE (DINT) / IsFirstScan (BOOL)
// ===============================================================

// ===============================================================
// 功能段 1: 首次扫描初始化(写入默认整定值)
// ===============================================================
// 判据: 若某通道 Cfg_SP2 <= 0 视为"未整定", 按所属组写入默认值。
// 仅在上电后第一个扫描周期执行, 此后参数由 HMI 维护并掉电保持。
IF IsFirstScan THEN
    FOR i := 0 TO 15 DO
        IF HMI_CMD.Cfg_SP2[i] <= 0.0 THEN
            IF i <= 5 THEN
                HMI_CMD.Cfg_SP1[i] := 130.0;  HMI_CMD.Cfg_SP2[i] := 145.0;
            ELSIF i <= 9 THEN
                HMI_CMD.Cfg_SP1[i] := 85.0;   HMI_CMD.Cfg_SP2[i] := 95.0;
            ELSIF i <= 13 THEN
                HMI_CMD.Cfg_SP1[i] := 80.0;   HMI_CMD.Cfg_SP2[i] := 90.0;
            ELSE
                HMI_CMD.Cfg_SP1[i] := 75.0;   HMI_CMD.Cfg_SP2[i] := 85.0;
            END_IF;
            HMI_CMD.Cfg_Hys[i]  := 3.0;
            HMI_CMD.Cfg_Dly1[i] := 3;
            HMI_CMD.Cfg_Dly2[i] := 2;
            HMI_CMD.Cfg_Enable[i] := 1;
        END_IF;
    END_FOR;
    IsFirstScan := 0;
END_IF;

// ===============================================================
// 功能段 2: 批量参数写入(权限校验 + 按组下发)
// ===============================================================
// HMI 置位 Apply_Batch 发起批量修改:
//   B_Group 选择目标组: 0=全部16路 1=定子 2=电机轴承 3=泵轴承 4=减速机油
//   B_SP1/B_SP2/B_Hys/B_Dly1/B_Dly2 为统一下发的整定值
//   B_EnableOpt: 0=不修改使能 1=批量启用 2=批量禁用
// 安全规则:
//   - User_Level < 2 时拒绝写入(事件类型6: 越权操作);
//   - 合法性检查: 要求 SP2 > SP1 且 Hys >= 0, 防止误设颠倒阈值;
//   - 写入成功后记录事件(类型5), 便于参数修改审计追溯。
IF HMI_CMD.Apply_Batch THEN
    IF HMI_CMD.User_Level >= 2 THEN
        IF (HMI_CMD.B_SP2 > HMI_CMD.B_SP1) AND (HMI_CMD.B_Hys >= 0.0) THEN

            // 由组号换算通道下标范围 [GS, GE]
            CASE HMI_CMD.B_Group OF
                1: GS := 0;   GE := 5;     // 电机定子
                2: GS := 6;   GE := 9;     // 电机轴承
                3: GS := 10;  GE := 13;    // 渣浆泵轴承
                4: GS := 14;  GE := 15;    // 减速机油
                ELSE GS := 0; GE := 15;    // 0 及其他: 全部
            END_CASE;

            FOR i := GS TO GE DO
                HMI_CMD.Cfg_SP1[i] := HMI_CMD.B_SP1;
                HMI_CMD.Cfg_SP2[i] := HMI_CMD.B_SP2;
                HMI_CMD.Cfg_Hys[i] := HMI_CMD.B_Hys;
                HMI_CMD.Cfg_Dly1[i] := HMI_CMD.B_Dly1;
                HMI_CMD.Cfg_Dly2[i] := HMI_CMD.B_Dly2;
                IF HMI_CMD.B_EnableOpt = 1 THEN
                    HMI_CMD.Cfg_Enable[i] := 1;
                ELSIF HMI_CMD.B_EnableOpt = 2 THEN
                    HMI_CMD.Cfg_Enable[i] := 0;
                END_IF;
            END_FOR;

            // 事件: 类型5 = 批量参数修改成功 (Evt_Ch 记录目标组号)
            HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]   := HMI_CMD.B_Group;
            HMI_CMD.Evt_Type[HMI_CMD.Evt_Head] := 5;
            HMI_CMD.Evt_PV[HMI_CMD.Evt_Head]   := 0.0;
            HMI_CMD.Evt_H[HMI_CMD.Evt_Head]    := Hour;
            HMI_CMD.Evt_M[HMI_CMD.Evt_Head]    := Minute;
            HMI_CMD.Evt_S[HMI_CMD.Evt_Head]    := Second;
            HMI_CMD.Evt_Head := (HMI_CMD.Evt_Head + 1) MOD 32;
        END_IF;
    ELSE
        // 事件: 类型6 = 越权修改被拒绝
        HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]   := HMI_CMD.B_Group;
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
// 每路通道依次执行:
//   1) 使能判断: 禁用通道强制解除报警并复位定时器;
//   2) 一级报警: 条件(PV>=SP1)驱动 TON 防抖, 延时到后置位;
//                 PV < SP1-Hys 时立即解除(回差);
//   3) 二级报警: 与一级同构, 但使用 SP2/Dly2;
//   4) 边沿检测: 置位/解除瞬间写入事件环形缓冲(类型1..4)。
// 说明: 每路使用独立的 Tmr1[i]/Tmr2[i] 与 PrevAlm*[i],
//       16 路互不影响, 任何一路动作不改变其余通道状态。
FOR i := 0 TO 15 DO

    // ---------- 通道禁用时: 强制安全状态 ----------
    IF NOT HMI_CMD.Cfg_Enable[i] THEN
        HMI_CMD.Sta_Alm1[i] := 0;
        HMI_CMD.Sta_Alm2[i] := 0;
        Tmr1[i].TimerEnable := 0;
        Tmr1[i].PRE := 0;
        TON(Tmr1[i]);
        Tmr2[i].TimerEnable := 0;
        Tmr2[i].PRE := 0;
        TON(Tmr2[i]);

    ELSE
        // ---------- 一级报警(预警) ----------
        // 防抖定时器: PV 连续 >= SP1 达到 Dly1 秒后 DN 置位
        Tmr1[i].PRE := HMI_CMD.Cfg_Dly1[i] * 1000;   // 秒 -> 毫秒
        Tmr1[i].TimerEnable := (HMI_CMD.PV[i] >= HMI_CMD.Cfg_SP1[i]);
        TON(Tmr1[i]);

        // 回差解除: PV 跌回 SP1-Hys 以下, 立即解除并复位定时器
        IF HMI_CMD.PV[i] < (HMI_CMD.Cfg_SP1[i] - HMI_CMD.Cfg_Hys[i]) THEN
            HMI_CMD.Sta_Alm1[i] := 0;
            Tmr1[i].TimerEnable := 0;
            TON(Tmr1[i]);
        ELSIF Tmr1[i].DN THEN
            HMI_CMD.Sta_Alm1[i] := 1;
        END_IF;

        // ---------- 二级报警(停机) ----------
        Tmr2[i].PRE := HMI_CMD.Cfg_Dly2[i] * 1000;
        Tmr2[i].TimerEnable := (HMI_CMD.PV[i] >= HMI_CMD.Cfg_SP2[i]);
        TON(Tmr2[i]);

        IF HMI_CMD.PV[i] < (HMI_CMD.Cfg_SP2[i] - HMI_CMD.Cfg_Hys[i]) THEN
            HMI_CMD.Sta_Alm2[i] := 0;
            Tmr2[i].TimerEnable := 0;
            TON(Tmr2[i]);
        ELSIF Tmr2[i].DN THEN
            HMI_CMD.Sta_Alm2[i] := 1;
        END_IF;
    END_IF;

    // ---------- 事件记录: 边沿检测(类型1..4) ----------
    // 类型1=一级产生 2=一级解除 3=二级产生 4=二级解除
    IF HMI_CMD.Sta_Alm1[i] AND NOT PrevAlm1[i] THEN
        HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]   := i;
        HMI_CMD.Evt_Type[HMI_CMD.Evt_Head] := 1;
        HMI_CMD.Evt_PV[HMI_CMD.Evt_Head]   := HMI_CMD.PV[i];
        HMI_CMD.Evt_H[HMI_CMD.Evt_Head]    := Hour;
        HMI_CMD.Evt_M[HMI_CMD.Evt_Head]    := Minute;
        HMI_CMD.Evt_S[HMI_CMD.Evt_Head]    := Second;
        HMI_CMD.Evt_Head := (HMI_CMD.Evt_Head + 1) MOD 32;
    ELSIF (NOT HMI_CMD.Sta_Alm1[i]) AND PrevAlm1[i] THEN
        HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]   := i;
        HMI_CMD.Evt_Type[HMI_CMD.Evt_Head] := 2;
        HMI_CMD.Evt_PV[HMI_CMD.Evt_Head]   := HMI_CMD.PV[i];
        HMI_CMD.Evt_H[HMI_CMD.Evt_Head]    := Hour;
        HMI_CMD.Evt_M[HMI_CMD.Evt_Head]    := Minute;
        HMI_CMD.Evt_S[HMI_CMD.Evt_Head]    := Second;
        HMI_CMD.Evt_Head := (HMI_CMD.Evt_Head + 1) MOD 32;
    END_IF;

    IF HMI_CMD.Sta_Alm2[i] AND NOT PrevAlm2[i] THEN
        HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]   := i;
        HMI_CMD.Evt_Type[HMI_CMD.Evt_Head] := 3;
        HMI_CMD.Evt_PV[HMI_CMD.Evt_Head]   := HMI_CMD.PV[i];
        HMI_CMD.Evt_H[HMI_CMD.Evt_Head]    := Hour;
        HMI_CMD.Evt_M[HMI_CMD.Evt_Head]    := Minute;
        HMI_CMD.Evt_S[HMI_CMD.Evt_Head]    := Second;
        HMI_CMD.Evt_Head := (HMI_CMD.Evt_Head + 1) MOD 32;
    ELSIF (NOT HMI_CMD.Sta_Alm2[i]) AND PrevAlm2[i] THEN
        HMI_CMD.Evt_Ch[HMI_CMD.Evt_Head]   := i;
        HMI_CMD.Evt_Type[HMI_CMD.Evt_Head] := 4;
        HMI_CMD.Evt_PV[HMI_CMD.Evt_Head]   := HMI_CMD.PV[i];
        HMI_CMD.Evt_H[HMI_CMD.Evt_Head]    := Hour;
        HMI_CMD.Evt_M[HMI_CMD.Evt_Head]    := Minute;
        HMI_CMD.Evt_S[HMI_CMD.Evt_Head]    := Second;
        HMI_CMD.Evt_Head := (HMI_CMD.Evt_Head + 1) MOD 32;
    END_IF;

    PrevAlm1[i] := HMI_CMD.Sta_Alm1[i];
    PrevAlm2[i] := HMI_CMD.Sta_Alm2[i];
END_FOR;

// ===============================================================
// 功能段 4: 报警汇总与停机输出
// ===============================================================
// 统计当前处于一级/二级报警的通道数, 并生成两个总出口:
//   Out_Warn: >=1 路一级报警 -> 接 HMI 声光预警;
//   Out_Trip: >=1 路二级报警 -> 接停机联锁回路。
HMI_CMD.Alm1_Count := 0;
HMI_CMD.Alm2_Count := 0;
FOR i := 0 TO 15 DO
    IF HMI_CMD.Sta_Alm1[i] THEN
        HMI_CMD.Alm1_Count := HMI_CMD.Alm1_Count + 1;
    END_IF;
    IF HMI_CMD.Sta_Alm2[i] THEN
        HMI_CMD.Alm2_Count := HMI_CMD.Alm2_Count + 1;
    END_IF;
END_FOR;

HMI_CMD.Any_Alm1 := (HMI_CMD.Alm1_Count > 0);
HMI_CMD.Any_Alm2 := (HMI_CMD.Alm2_Count > 0);
Out_Warn := HMI_CMD.Any_Alm1;
Out_Trip := HMI_CMD.Any_Alm2;

// ===============================================================
// 功能段 5: 事件记录清空命令
// ===============================================================
// HMI 置位 Reset_Log 时清空环形缓冲与写指针, 用于检修后重新起录。
IF HMI_CMD.Reset_Log THEN
    FOR i := 0 TO 31 DO
        HMI_CMD.Evt_Ch[i]   := 0;
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
// 功能段 6: 启用状态输出
// ===============================================================
// EnableOut 跟随 EnableIn, 用于在梯形图中级联使能
EnableOut := EnableIn;

// ===============================================================
// 程序结束
// ===============================================================
