// ===============================================================
// AOI 名称: FlowRateTot (流量累计系统)
// 版本: 1.1
// 编程语言: Structured Text (ST)
// 适用平台: Studio 5000 (ControlLogix/CompactLogix)
// ===============================================================
// 功能概述:
// 1. 根据流量计瞬时流量计算累计量,核心公式: 累计量 = 瞬时流量 × 时间间隔
// 2. 支持总累计、分钟累计、天累计、月累计
// 3. 增加流量有效性判断: 流量超出上下限范围时停止累计并输出报警
// 4. 采用双寄存器累加方案(DINT+REAL),避免REAL精度溢出导致累加停滞
// ===============================================================
// 双寄存器累加原理:
// - 使用 DINT 存储整数部分(最大约 +/-21亿)
// - 使用 REAL 存储小数部分(0.0~1.0)
// - 每次累加时,小数部分超过 1.0 则向整数部分进位
// - 最终值 = INT_TO_REAL(Int) + Frac
// ===============================================================
// 功能段 1: 流量有效性判断与积分增量计算
// ===============================================================

Is_Flow_Valid := (In_Flow_Rate >= In_Flow_Min) AND (In_Flow_Rate <= In_Flow_Max);

IF Is_Flow_Valid THEN
    Flow_Increment := In_Flow_Rate * In_Scan_Time / 3600000.0;
ELSE
    Flow_Increment := 0.0;
END_IF;

Out_Alarm_Flow_Invalid := NOT Is_Flow_Valid;

// ===============================================================
// 功能段 2: 总累计与分钟累计
// ===============================================================

IF In_Run AND Is_Flow_Valid THEN
    Out_Tot_Frac := Out_Tot_Frac + Flow_Increment;
    WHILE Out_Tot_Frac >= 1.0 DO
        Out_Tot_Int := Out_Tot_Int + 1;
        Out_Tot_Frac := Out_Tot_Frac - 1.0;
    END_WHILE;
    WHILE Out_Tot_Frac < 0.0 DO
        Out_Tot_Int := Out_Tot_Int - 1;
        Out_Tot_Frac := Out_Tot_Frac + 1.0;
    END_WHILE;

    Temp_Min := Temp_Min + Flow_Increment;
END_IF;

Out_Tot := INT_TO_REAL(Out_Tot_Int) + Out_Tot_Frac;

TONR_01.PRE := In_Tot_Min * 60000;
TONR_01.Reset := TONR_01.DN;
TONR_01.TimerEnable := In_Run;
TONR(TONR_01);

IF TONR_01.DN THEN
    Out_Tot_Min := Temp_Min;
    Temp_Min := 0;
END_IF;

// ===============================================================
// 功能段 3: 天累计
// ===============================================================

IF In_Run AND Is_Flow_Valid THEN
    Temp_Day := Temp_Day + Flow_Increment;
END_IF;

Out_Tot_D_RT := Temp_Day;

IF (Hour = In_Day_Time_Hour) AND (Minute = In_Day_Time_Minute) AND (Second <= 1) THEN
    Out_Tot_D := Temp_Day;
    Out_Tot_D_RT := 0;
END_IF;

IF (Hour = In_Day_Time_Hour) AND (Minute = In_Day_Time_Minute) AND (Second >= 2) AND (Second <= 3) THEN
    Temp_Day := 0;
END_IF;

// ===============================================================
// 功能段 4: 月累计
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

IF (Day >= 1) AND (Day <= Days_In_Month) AND In_Run AND Is_Flow_Valid THEN
    Temp_Month := Temp_Month + Flow_Increment;
END_IF;

IF (Day >= 1) AND (Day <= Days_In_Month) THEN
    Out_Tot_M_RT := Temp_Month;
END_IF;

IF (Day = 1) AND (Hour = 0) AND (Minute = 0) AND (Second <= 1) THEN
    Out_Tot_M := Temp_Month;
    Out_Tot_M_RT := 0;
END_IF;

IF (Day = 1) AND (Hour = 0) AND (Minute = 0) AND (Second >= 2) AND (Second <= 3) THEN
    Temp_Month := 0;
END_IF;

// ===============================================================
// 功能段 5: HMI 命令处理
// ===============================================================

IF HMI_CMD.Clear THEN
    Out_Tot := 0;
    Out_Tot_Int := 0;
    Out_Tot_Frac := 0.0;
    Out_Tot_Min := 0;
    Out_Tot_D_RT := 0;
    Out_Tot_M_RT := 0;
    Out_Tot_D := 0;
    Out_Tot_M := 0;

    Temp_Min := 0;
    Temp_Day := 0;
    Temp_Month := 0;

    HMI_CMD.Clear := 0;
END_IF;

// ===============================================================
// 功能段 6: HMI 数据同步
// ===============================================================

HMI_CMD.Out_Tot := Out_Tot;
HMI_CMD.Out_Tot_Min := Out_Tot_Min;
HMI_CMD.Out_Tot_D_RT := Out_Tot_D_RT;
HMI_CMD.Out_Tot_M_RT := Out_Tot_M_RT;
HMI_CMD.Out_Tot_D := Out_Tot_D;
HMI_CMD.Out_Tot_M := Out_Tot_M;
HMI_CMD.Alarm_Flow_Invalid := Out_Alarm_Flow_Invalid;

// ===============================================================
// 功能段 7: 启用状态输出
// ===============================================================

EnableOut := EnableIn;

// ===============================================================
// 程序结束
// ===============================================================