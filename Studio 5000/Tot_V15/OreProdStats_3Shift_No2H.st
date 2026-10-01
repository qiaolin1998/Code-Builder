// ===============================================================
// AOI 名称: OreProdStats_3Shift_No2H (三班制产量统计系统 - 无2小时分段)
// 版本: 1.0
// 编程语言: Structured Text (ST)
// 适用平台: Studio 5000 (ControlLogix/CompactLogix)
// ===============================================================
// 功能概述:
// 1. 在保留原 OreProdStats AOI 功能(总/分钟/天/月统计)的基础上,实现固定时间的三班制产量统计,去除每2小时的单独累计;
// 2. 三个班次的时间范围固定如下:
//    - 早班: 09:00 – 17:00
//    - 中班: 17:00 – 次日 01:00 (跨越午夜)
//    - 晚班: 01:00 – 09:00
// 3. 每个班次提供:
//    - 班实时累计: 当前正在运行班次在本班周期内的实时总产量;
//    - 班历史累计: 上一次完成的该班的总产量(在班切换时冻结);
// ===============================================================
// 设计说明:
// 1. 时间基准:
//    - 使用系统时间 Year/Month/Day/Hour/Minute/Second;
//    - 计算 Time_Real = Hour * 60 + Minute (范围 0..1439),作为一天内统一的“分钟计数”时间轴。
// 2. 班次判定:
//    - 班次通过比较 Time_Real 与三个固定时间点(9:00、17:00、1:00)自动判定,跨午夜的情况单独处理;
//    - Shift_ID = 1: 早班  09:00–17:00
//    - Shift_ID = 2: 中班  17:00–次日 01:00 (跨午夜)
//    - Shift_ID = 3: 晚班  01:00–09:00
// 3. 累计策略:
//    - 以 OSRI 检测到的脉冲上升沿为触发,在对应班次的临时变量上累加产量;
//    - 在班切换时,将本班临时累计拷贝到历史班累计输出,随后清零临时值;
//    - 班切换时间固定: 早班结束=中班开始(17:00),中班结束=晚班开始(01:00),晚班结束=早班开始(09:00)。
// 4. 与原 AOI 的兼容:
//    - 总累计/分钟累计/天累计/月累计逻辑完全沿用原 OreProdStats 程序,保证统计口径一致;
//    - 原 AOI 中与班次相关的时间输入(In_Class1/2_Time_*)仍被保留,用于天/月切换等场景。
// ===============================================================
// 变量约定(相对原 OreProdStats 的扩展部分):
// 1. 输出(历史班累计):
//    - Out_Tot_Shift1, Out_Tot_Shift2, Out_Tot_Shift3 : DINT;   // 分别表示早/中/晚班上一个完成班次的总产量
// 2. 输出(实时班累计):
//    - Out_Tot_Shift1_RT, Out_Tot_Shift2_RT, Out_Tot_Shift3_RT : DINT; // 各自班当前周期内的实时累计
//    - Out_Tot_Shift_RT : DINT;                                        // 当前班的实时累计(根据 Shift_ID 选取)
// 3. 本地变量(班临时累计):
//    - TempShift1, TempShift2, TempShift3 : DINT;
//      用于在当前班周期内累加产量,在班结束时拷贝到 Out_Tot_ShiftX 并清零。
// 4. 本地变量(班次辅助):
//    - Shift_ID : DINT;  // 当前班号(1=早班, 2=中班, 3=晚班)
// ===============================================================

// ===============================================================
// 功能段 1: 脉冲检测与总累计
// 与原 OreProdStats 相同
// ===============================================================

// 脉冲上升沿检测
OSRI_Pulse.InputBit := In_Pulse;
OSRI(OSRI_Pulse);

// 总累计计数
IF OSRI_Pulse.OutputBit AND In_Run THEN
    Out_Tot := Out_Tot + In_Scale;
    Temp[0] := Temp[0] + In_Scale;   // 分钟累计临时量
END_IF;

// ===============================================================
// 功能段 2: 分钟累计
// 与原 OreProdStats 相同
// ===============================================================

TONR_01.PRE := In_Tot_Min * 60000;
TONR_01.Reset := TONR_01.DN;
TONR_01.TimerEnable := In_Run;
TONR(TONR_01);

IF TONR_01.DN THEN
    Out_Tot_Min := Temp[0];
    Temp[0] := 0;
END_IF;

// ===============================================================
// 功能段 3: 时间数据准备
// 与原 OreProdStats 相同,并在此基础上增加三班制辅助变量
// ===============================================================

// 系统时间 -> 数组
Time[0] := Year;
Time[1] := Month;
Time[2] := Day;
Time[3] := Hour;
Time[4] := Minute;
Time[5] := Second;

// 当前时间的分钟偏移量 (0..1439)
Time_Real := Hour * 60 + Minute;

// 原班次/天切换时间计算(保留天/月逻辑需要)
Time_Set1 := In_Class1_Time_Hour * 60 + In_Class1_Time_Minute;
Time_Set2 := In_Class2_Time_Hour * 60 + In_Class2_Time_Minute;
Time_Set3_Day := In_Day_Time_Hour * 60 + In_Day_Time_Minute;

// ===============================================================
// 功能段 4: 三班制班次判定
// ===============================================================

// 班次判定:
// Shift_ID = 1: 早班  09:00–17:00
// Shift_ID = 2: 中班  17:00–次日 01:00 (跨午夜)
// Shift_ID = 3: 晚班  01:00–09:00
IF (Time_Real >= 9 * 60) AND (Time_Real < 17 * 60) THEN
    Shift_ID := 1;  // 早班
ELSIF (Time_Real >= 17 * 60) OR (Time_Real < 1 * 60) THEN
    Shift_ID := 2;  // 中班(跨午夜)
ELSE
    Shift_ID := 3;  // 晚班
END_IF;

// ===============================================================
// 功能段 5: 三班制班累计
// ===============================================================

// 在脉冲处进行三班累计
IF OSRI_Pulse.OutputBit AND In_Run THEN
    // 班累计临时值
    CASE Shift_ID OF
        1:  TempShift1 := TempShift1 + In_Scale;
        2:  TempShift2 := TempShift2 + In_Scale;
        3:  TempShift3 := TempShift3 + In_Scale;
    END_CASE;
END_IF;

// 班实时累计输出
Out_Tot_Shift1_RT := TempShift1;
Out_Tot_Shift2_RT := TempShift2;
Out_Tot_Shift3_RT := TempShift3;

// 当前班实时累计(用于 HMI 显示“当前班产量”)
CASE Shift_ID OF
    1: Out_Tot_Shift_RT := Out_Tot_Shift1_RT;
    2: Out_Tot_Shift_RT := Out_Tot_Shift2_RT;
    3: Out_Tot_Shift_RT := Out_Tot_Shift3_RT;
END_CASE;

// ===============================================================
// 功能段 6: 班结束时保存班累计并清零
// 班切换时间固定:
//   早班结束=中班开始: 17:00
//   中班结束=晚班开始: 01:00
//   晚班结束=早班开始: 09:00
// 逻辑与原白/夜班逻辑类似,先冻结历史值,再延迟 2 秒清零临时量
// ===============================================================

// 早班结束 / 中班开始: 17:00
IF (Hour = 17) AND (Minute = 0) AND (Second <= 1) THEN
    Out_Tot_Shift1 := TempShift1;
    Out_Tot_Shift1_RT := 0;
END_IF;

IF (Hour = 17) AND (Minute = 0) AND (Second >= 2) AND (Second <= 3) THEN
    TempShift1 := 0;
END_IF;

// 中班结束 / 晚班开始: 01:00
IF (Hour = 1) AND (Minute = 0) AND (Second <= 1) THEN
    Out_Tot_Shift2 := TempShift2;
    Out_Tot_Shift2_RT := 0;
END_IF;

IF (Hour = 1) AND (Minute = 0) AND (Second >= 2) AND (Second <= 3) THEN
    TempShift2 := 0;
END_IF;

// 晚班结束 / 早班开始: 09:00
IF (Hour = 9) AND (Minute = 0) AND (Second <= 1) THEN
    Out_Tot_Shift3 := TempShift3;
    Out_Tot_Shift3_RT := 0;
END_IF;

IF (Hour = 9) AND (Minute = 0) AND (Second >= 2) AND (Second <= 3) THEN
    TempShift3 := 0;
END_IF;

// ===============================================================
// 功能段 7: 天累计逻辑
// 直接复用原 OreProdStats 的实现
// ===============================================================

IF OSRI_Pulse.OutputBit AND In_Run THEN
    Temp[8] := Temp[8] + In_Scale;
END_IF;

Out_Tot_D_RT := Temp[8];

IF (Hour = In_Day_Time_Hour) AND (Minute = In_Day_Time_Minute) AND (Second <= 1) THEN
    Out_Tot_D := Temp[8];
    Out_Tot_D_RT := 0;
END_IF;

IF (Hour = In_Day_Time_Hour) AND (Minute = In_Day_Time_Minute) AND (Second >= 2) AND (Second <= 3) THEN
    Temp[8] := 0;
END_IF;

// ===============================================================
// 功能段 8: 月累计逻辑(与原 OreProdStats 相同)
// ===============================================================

Is_Leap_Year := (Year MOD 4 = 0) AND (Year MOD 100 <> 0) OR (Year MOD 400 = 0);

CASE Month OF
    1, 3, 5, 7, 8, 10, 12: Days_In_Month := 31;
    4, 6, 9, 11: Days_In_Month := 30;
    2:
        IF Is_Leap_Year THEN
            Days_In_Month := 29;
        ELSE
            Days_In_Month := 28;
        END_IF;
END_CASE;

IF (Day >= 1) AND (Day <= Days_In_Month) AND OSRI_Pulse.OutputBit AND In_Run THEN
    Temp[4] := Temp[4] + In_Scale;
END_IF;

IF (Day >= 1) AND (Day <= Days_In_Month) THEN
    Out_Tot_M_RT := Temp[4];
END_IF;

IF (Day = 1) AND (Hour = 0) AND (Minute = 0) AND (Second <= 1) THEN
    Out_Tot_M := Temp[4];
    Out_Tot_M_RT := 0;
END_IF;

IF (Day = 1) AND (Hour = 0) AND (Minute = 0) AND (Second >= 2) AND (Second <= 3) THEN
    Temp[4] := 0;
END_IF;

// ===============================================================
// 功能段 9: HMI 命令处理(三班累计)
// ===============================================================

IF HMI_CMD.Clear THEN
    // 清零原有输出累计值
    Out_Tot := 0;
    Out_Tot_Min := 0;
    Out_Tot_D_RT := 0;
    Out_Tot_M_RT := 0;
    Out_Tot_D := 0;
    Out_Tot_M := 0;

    // 清零三班累计(历史与实时)
    Out_Tot_Shift1 := 0;
    Out_Tot_Shift2 := 0;
    Out_Tot_Shift3 := 0;

    Out_Tot_Shift1_RT := 0;
    Out_Tot_Shift2_RT := 0;
    Out_Tot_Shift3_RT := 0;
    Out_Tot_Shift_RT := 0;

    // 清零临时累计变量
    Temp[0] := 0;   // 分钟累计
    Temp[4] := 0;   // 月累计
    Temp[8] := 0;   // 天累计

    TempShift1 := 0;
    TempShift2 := 0;
    TempShift3 := 0;

    // 复位清除命令
    HMI_CMD.Clear := 0;
END_IF;

// ===============================================================
// 功能段 10: HMI 数据同步
// ===============================================================

HMI_CMD.Out_Tot := Out_Tot;
HMI_CMD.Out_Tot_Min := Out_Tot_Min;
HMI_CMD.Out_Tot_D_RT := Out_Tot_D_RT;
HMI_CMD.Out_Tot_M_RT := Out_Tot_M_RT;
HMI_CMD.Out_Tot_D := Out_Tot_D;
HMI_CMD.Out_Tot_M := Out_Tot_M;

// 三班累计
HMI_CMD.Out_Tot_Shift1 := Out_Tot_Shift1;
HMI_CMD.Out_Tot_Shift2 := Out_Tot_Shift2;
HMI_CMD.Out_Tot_Shift3 := Out_Tot_Shift3;
HMI_CMD.Out_Tot_Shift1_RT := Out_Tot_Shift1_RT;
HMI_CMD.Out_Tot_Shift2_RT := Out_Tot_Shift2_RT;
HMI_CMD.Out_Tot_Shift3_RT := Out_Tot_Shift3_RT;
HMI_CMD.Out_Tot_Shift_RT := Out_Tot_Shift_RT;

// ===============================================================
// 功能段 11: 启用状态输出
// ===============================================================

EnableOut := EnableIn;

// ===============================================================
// 程序结束
// ===============================================================
