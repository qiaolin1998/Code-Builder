// ===============================================================
// AOI 名称: OreProdStats (产量统计系统)
// 版本: 1.2 (优化版)
// 编程语言: Structured Text (ST)
// 适用平台: Studio 5000 (ControlLogix/CompactLogix)
// ===============================================================
// 功能概述:
// 本程序实现一个多维度的产量累计统计系统,支持以下时间维度的累计:
// 1. 总累计 - 从系统启动开始的累计值
// 2. 分钟累计 - 每n分钟的累计值
// 3. 班累计 - 白班/夜班的累计值
// 4. 天累计 - 每天的累计值
// 5. 月累计 - 每月的累计值
// ===============================================================
// 核心设计理念:
// 1. 实时累计与历史累计分离: 实时累计值随时间变化,历史累计值在切换时刻冻结
// 2. 自动切换: 根据系统时间自动判断当前时间段,切换累计维度
// 3. 数据持久化: 历史累计值在切换时刻保存,不会丢失
// 4. 可配置性: 班次时间、累计周期等参数可通过输入参数配置
// ===============================================================
// 变量命名规范:
// - 输入参数: In_xxx (如 In_Pulse, In_Run)
// - 输出参数: Out_xxx (如 Out_Tot, Out_Tot_Min)
// - 实时累计: xxx_RT (如 Out_Tot_Class_RT, Out_Tot_D_RT)
// - 临时变量: Temp[索引] (如 Temp[0], Temp[8])
// - 时间设置: Time_Setxxx (如 Time_Set1, Time_Set2)
// ===============================================================
// 功能段划分:
// 1. 脉冲检测与总累计
// 2. 分钟累计
// 3. 时间数据准备
// 4. 白班累计逻辑
// 5. 夜班累计逻辑
// 6. 班实时累计输出
// 7. 天累计逻辑
// 8. 月累计逻辑
// 9. HMI 命令处理
// 10. HMI 数据同步
// 11. 启用状态输出
// ===============================================================

// ===============================================================
// 功能段 1: 脉冲检测与总累计
// 执行频率: 每次扫描
// 说明: 检测输入脉冲的上升沿,并进行总累计计数
// ===============================================================
// 脉冲上升沿检测
// OSRI (One Shot Rising Input) 指令用于检测输入信号的上升沿
// 当 In_Pulse 从 0 变为 1 时,OSRI_Pulse.OutputBit 会产生一个扫描周期的脉冲
OSRI_Pulse.InputBit := In_Pulse;
OSRI(OSRI_Pulse);

// 总累计计数
// 条件: 检测到脉冲上升沿 (OSRI_Pulse.OutputBit) 且设备处于运行状态 (In_Run)
// 操作: 
// 1. 将 In_Scale (缩放系数) 累加到 Out_Tot (总累计输出)
// 2. 同时累加到 Temp[0] (分钟累计临时变量)
// 说明: 总累计值会一直累加,不会自动清零,只能通过 HMI 清除命令清零
IF OSRI_Pulse.OutputBit AND In_Run THEN
    Out_Tot := Out_Tot + In_Scale;
    Temp[0] := Temp[0] + In_Scale;
END_IF;

// ===============================================================
// 功能段 2: 分钟累计
// 执行频率: 每次扫描
// 说明: 使用 TONR 定时器实现 n 分钟累计功能
// ===============================================================
// TONR (Timer On-Delay Retentive) 定时器配置
// PRE (预设值): In_Tot_Min (分钟数) * 60000 (转换为毫秒)
// Reset (复位): 当定时器完成 (DN=1) 时自动复位
// TimerEnable (使能): 仅在设备运行时 (In_Run=1) 计时
TONR_01.PRE := In_Tot_Min * 60000;
TONR_01.Reset := TONR_01.DN;
TONR_01.TimerEnable := In_Run;
TONR(TONR_01);

// 定时器完成处理
// 当定时器计时到达预设值时 (DN=1):
// 1. 将 Temp[0] 的值赋给 Out_Tot_Min (分钟累计输出)
// 2. 清零 Temp[0],开始下一个周期的累计
// 说明: 这样可以实现每 n 分钟更新一次分钟累计值
IF TONR_01.DN THEN
    Out_Tot_Min := Temp[0];
    Temp[0] := 0;
END_IF;

// ===============================================================
// 功能段 3: 时间数据准备
// 执行频率: 每次扫描
// 说明: 读取系统时间,计算时间偏移量和时间设置
// ===============================================================
// 读取系统时间到时间数组
// Time[0] = 年份 (如: 2024)
// Time[1] = 月份 (1-12)
// Time[2] = 日期 (1-31)
// Time[3] = 小时 (0-23)
// Time[4] = 分钟 (0-59)
// Time[5] = 秒 (0-59)
Time[0] := Year;
Time[1] := Month;
Time[2] := Day;
Time[3] := Hour;
Time[4] := Minute;
Time[5] := Second;

// 计算当前时间的分钟偏移量
// 公式: 小时 * 60 + 分钟
// 例如: 08:30 = 8 * 60 + 30 = 510 分钟
// 用途: 用于比较当前时间是否在某个时间段内
Time_Real := Hour * 60 + Minute;

// 计算班次切换时间的分钟偏移量
// Time_Set1: 白班开始时间 (如 08:00 = 480 分钟)
// Time_Set2: 夜班开始时间 (如 20:00 = 1200 分钟)
// Time_Set3_Day: 天切换时间 (如 00:00 = 0 分钟)
// 说明: 这些时间由用户通过输入参数配置
Time_Set1 := In_Class1_Time_Hour * 60 + In_Class1_Time_Minute;
Time_Set2 := In_Class2_Time_Hour * 60 + In_Class2_Time_Minute;
Time_Set3_Day := In_Day_Time_Hour * 60 + In_Day_Time_Minute;

// ===============================================================
// 功能段 4: 白班累计逻辑
// 执行频率: 每次扫描
// 说明: 在白班时间段内进行累计计数
// 典型时间段: 08:00 - 20:00 (可配置)
// ===============================================================
// 白班累计计数
// 条件:
// 1. 当前时间在白班时间段内 (Time_Real >= Time_Set1 AND Time_Real < Time_Set2)
// 2. 检测到脉冲上升沿 (OSRI_Pulse.OutputBit)
// 3. 设备处于运行状态 (In_Run)
// 操作: 将 In_Scale 累加到 Temp[10] (白班临时累计变量)
// 说明: Temp[10] 用于临时存储白班的累计值
IF (Time_Real >= Time_Set1) AND (Time_Real < Time_Set2) AND OSRI_Pulse.OutputBit AND In_Run THEN
    Temp[10] := Temp[10] + In_Scale;
END_IF;

// 更新白班实时累计值
// 条件: 当前时间在白班时间段内
// 操作: 将 Temp[10] 的值赋给 Out_Tot_Class1_RT (白班实时累计)
// 说明: 实时累计值会随时间变化,用于 HMI 实时显示
IF (Time_Real >= Time_Set1) AND (Time_Real < Time_Set2) THEN
    Out_Tot_Class1_RT := Temp[10];
END_IF;

// 白班结束处理 - 保存累计值
// 触发条件: 到达夜班开始时间 (Hour = In_Class2_Time_Hour, Minute = In_Class2_Time_Minute)
// 且在 0-1 秒内 (Second <= 1)
// 操作:
// 1. 将 Temp[10] 的值赋给 Out_Tot_Class1 (白班累计,历史值)
// 2. 清零 Out_Tot_Class1_RT (白班实时累计)
// 说明: 这一步将白班的累计值冻结保存,不会再变化
IF (Hour = In_Class2_Time_Hour) AND (Minute = In_Class2_Time_Minute) AND (Second <= 1) THEN
    Out_Tot_Class1 := Temp[10];
    Out_Tot_Class1_RT := 0;
END_IF;

// 白班结束处理 - 清零临时变量
// 触发条件: 到达夜班开始时间后 2-3 秒
// 操作: 清零 Temp[10]
// 说明: 延迟 2 秒清零是为了确保累计值已保存,避免数据丢失
IF (Hour = In_Class2_Time_Hour) AND (Minute = In_Class2_Time_Minute) AND (Second >= 2) AND (Second <= 3) THEN
    Temp[10] := 0;
END_IF;

// ===============================================================
// 功能段 5: 夜班累计逻辑
// 执行频率: 每次扫描
// 说明: 在夜班时间段内进行累计计数
// 典型时间段: 20:00 - 次日 08:00 (可配置)
// ===============================================================
// 夜班累计计数
// 条件:
// 1. 当前时间在夜班时间段内 (Time_Real >= Time_Set2 OR Time_Real < Time_Set1)
//    说明: 夜班时间跨 midnight,所以使用 OR 条件
// 2. 检测到脉冲上升沿
// 3. 设备处于运行状态
// 操作: 将 In_Scale 累加到 Temp[11] (夜班临时累计变量)
IF (Time_Real >= Time_Set2) OR (Time_Real < Time_Set1) THEN
    IF OSRI_Pulse.OutputBit AND In_Run THEN
        Temp[11] := Temp[11] + In_Scale;
    END_IF;
    Out_Tot_Class2_RT := Temp[11];
END_IF;

// 夜班结束处理 - 保存累计值
// 触发条件: 到达白班开始时间且在 0-1 秒内
// 操作:
// 1. 将 Temp[11] 的值赋给 Out_Tot_Class2 (夜班累计,历史值)
// 2. 清零 Out_Tot_Class2_RT (夜班实时累计)
IF (Hour = In_Class1_Time_Hour) AND (Minute = In_Class1_Time_Minute) AND (Second <= 1) THEN
    Out_Tot_Class2 := Temp[11];
    Out_Tot_Class2_RT := 0;
END_IF;

// 夜班结束处理 - 清零临时变量
// 触发条件: 到达白班开始时间后 2-3 秒
// 操作: 清零 Temp[11]
IF (Hour = In_Class1_Time_Hour) AND (Minute = In_Class1_Time_Minute) AND (Second >= 2) AND (Second <= 3) THEN
    Temp[11] := 0;
END_IF;

// ===============================================================
// 功能段 6: 班实时累计输出
// 执行频率: 每次扫描
// 说明: 根据当前时间输出对应的班实时累计值
// ===============================================================
// 输出当前班次的实时累计值
// 条件判断:
// - 如果在白班时间段内,输出白班实时累计值
// - 否则,输出夜班实时累计值
// 说明: 这个输出用于 HMI 显示当前班次的实时产量
IF (Time_Real >= Time_Set1) AND (Time_Real < Time_Set2) THEN
    Out_Tot_Class_RT := Out_Tot_Class1_RT;
ELSE
    Out_Tot_Class_RT := Out_Tot_Class2_RT;
END_IF;

// ===============================================================
// 功能段 7: 天累计逻辑
// 执行频率: 每次扫描
// 说明: 在当天时间段内进行累计计数
// 典型切换时间: 00:00 (可配置)
// ===============================================================
// 天累计计数
// 条件:
// 1. 检测到脉冲上升沿 (OSRI_Pulse.OutputBit)
// 2. 设备处于运行状态 (In_Run)
// 操作: 将 In_Scale 累加到 Temp[8] (天临时累计变量)
// 说明: 天累计没有时间段限制,只要有脉冲就累加
IF OSRI_Pulse.OutputBit AND In_Run THEN
    Temp[8] := Temp[8] + In_Scale;
END_IF;

// 更新天实时累计值
// 操作: 将 Temp[8] 的值赋给 Out_Tot_D_RT (天实时累计)
// 说明: 天实时累计值随时间变化,用于 HMI 实时显示当日产量
Out_Tot_D_RT := Temp[8];

// 天结束处理 - 保存累计值
// 触发条件: 到达天切换时间且在 0-1 秒内
// 操作:
// 1. 将 Temp[8] 的值赋给 Out_Tot_D (昨天累计,历史值)
// 2. 清零 Out_Tot_D_RT (天实时累计)
// 说明: 这一步将昨天的累计值冻结保存
IF (Hour = In_Day_Time_Hour) AND (Minute = In_Day_Time_Minute) AND (Second <= 1) THEN
    Out_Tot_D := Temp[8];
    Out_Tot_D_RT := 0;
END_IF;

// 天结束处理 - 清零临时变量
// 触发条件: 到达天切换时间后 2-3 秒
// 操作: 清零 Temp[8]
IF (Hour = In_Day_Time_Hour) AND (Minute = In_Day_Time_Minute) AND (Second >= 2) AND (Second <= 3) THEN
    Temp[8] := 0;
END_IF;

// ===============================================================
// 功能段 8: 月累计逻辑 (优化版)
// 执行频率: 每次扫描
// 说明: 在当月时间段内进行累计计数
// 切换时间: 每月 1 日 00:00
// ===============================================================
// 判断是否为闰年
// 闰年规则:
// 1. 能被 4 整除但不能被 100 整除, OR
// 2. 能被 400 整除
// 说明: 闰年的 2 月有 29 天,平年的 2 月有 28 天
Is_Leap_Year := (Year MOD 4 = 0) AND (Year MOD 100 <> 0) OR (Year MOD 400 = 0);

// 计算当前月份的天数
// 使用 CASE 语句替代复杂的 IF 嵌套,提高可读性
// 月份天数规则:
// - 1,3,5,7,8,10,12 月: 31 天
// - 4,6,9,11 月: 30 天
// - 2 月: 28 天 (平年) 或 29 天 (闰年)
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

// 月累计计数
// 条件:
// 1. 当前日期在当月有效范围内 (Day >= 1 AND Day <= Days_In_Month)
// 2. 检测到脉冲上升沿
// 3. 设备处于运行状态
// 操作: 将 In_Scale 累加到 Temp[4] (月临时累计变量)
// 说明: 这个条件判断确保只在当月有效日期内累加
IF (Day >= 1) AND (Day <= Days_In_Month) AND OSRI_Pulse.OutputBit AND In_Run THEN
    Temp[4] := Temp[4] + In_Scale;
END_IF;

// 更新月实时累计值
// 条件: 当前日期在当月有效范围内
// 操作: 将 Temp[4] 的值赋给 Out_Tot_M_RT (月实时累计)
// 说明: 月实时累计值随时间变化,用于 HMI 实时显示当月产量
IF (Day >= 1) AND (Day <= Days_In_Month) THEN
    Out_Tot_M_RT := Temp[4];
END_IF;

// 月结束处理 - 保存累计值
// 触发条件: 每月 1 日 00:00 且在 0-1 秒内
// 操作:
// 1. 将 Temp[4] 的值赋给 Out_Tot_M (上个月累计,历史值)
// 2. 清零 Out_Tot_M_RT (月实时累计)
// 说明: 这一步将上个月的累计值冻结保存
IF (Day = 1) AND (Hour = 0) AND (Minute = 0) AND (Second <= 1) THEN
    Out_Tot_M := Temp[4];
    Out_Tot_M_RT := 0;
END_IF;

// 月结束处理 - 清零临时变量
// 触发条件: 每月 1 日 00:00 后 2-3 秒
// 操作: 清零 Temp[4]
IF (Day = 1) AND (Hour = 0) AND (Minute = 0) AND (Second >= 2) AND (Second <= 3) THEN
    Temp[4] := 0;
END_IF;

// ===============================================================
// 功能段 9: HMI 命令处理
// 执行频率: 每次扫描
// 说明: 处理 HMI 发送的控制命令
// ===============================================================
// 处理 HMI 清除命令
// 触发条件: HMI_CMD.Clear = 1 (HMI 发送清除命令)
// 操作: 清零所有累计值
// 说明: 这个操作用于手动重置累计系统
IF HMI_CMD.Clear THEN
    // 清零所有输出累计值
    Out_Tot := 0;
    Out_Tot_Min := 0;
    Out_Tot_Class_RT := 0;
    Out_Tot_D_RT := 0;
    Out_Tot_M_RT := 0;
    Out_Tot_D := 0;
    Out_Tot_M := 0;
    Out_Tot_Class1 := 0;
    Out_Tot_Class2 := 0;
    
    // 清零本地实时累计值
    Out_Tot_Class1_RT := 0;
    Out_Tot_Class2_RT := 0;
    
    // 清零临时累计变量
    Temp[0] := 0;   // 分钟累计
    Temp[4] := 0;   // 月累计 (31天月份)
    Temp[5] := 0;   // 月累计 (30天月份)
    Temp[6] := 0;   // 月累计 (2月闰年)
    Temp[7] := 0;   // 月累计 (2月平年)
    Temp[8] := 0;   // 天累计
    Temp[10] := 0;  // 白班累计
    Temp[11] := 0;  // 夜班累计
    
    // 清零 HMI 清除命令位 (防止重复执行)
    HMI_CMD.Clear := 0;
END_IF;

// ===============================================================
// 功能段 10: HMI 数据同步
// 执行频率: 每次扫描
// 说明: 将累计值同步到 HMI 命令块
// ===============================================================
// 同步累计值到 HMI 命令块
// 操作: 将所有累计输出值复制到 HMI_CMD 结构中
// 说明: 这一步用于 HMI 读取和显示累计值
HMI_CMD.Out_Tot := Out_Tot;
HMI_CMD.Out_Tot_Min := Out_Tot_Min;
HMI_CMD.Out_Tot_Class_RT := Out_Tot_Class_RT;
HMI_CMD.Out_Tot_D_RT := Out_Tot_D_RT;
HMI_CMD.Out_Tot_M_RT := Out_Tot_M_RT;
HMI_CMD.Out_Tot_D := Out_Tot_D;
HMI_CMD.Out_Tot_M := Out_Tot_M;
HMI_CMD.Out_Tot_Class1 := Out_Tot_Class1;
HMI_CMD.Out_Tot_Class2 := Out_Tot_Class2;

// ===============================================================
// 功能段 11: 启用状态输出
// 执行频率: 每次扫描
// 说明: 设置 AOI 的启用状态输出
// ===============================================================
// 设置 AOI 启用状态输出
// 操作: 将 EnableIn (输入启用状态) 复制到 EnableOut (输出启用状态)
// 说明: 这个输出用于指示 AOI 当前是否正在执行
EnableOut := EnableIn;

// ===============================================================
// 程序结束
// ===============================================================
// 总结:
// 本程序实现了一个完整的多维度产量累计统计系统,具有以下特点:
// 1. 支持 5 个时间维度的累计 (总/分钟/班/天/月)
// 2. 自动切换累计维度,无需人工干预
// 3. 实时累计与历史累计分离,数据安全可靠
// 4. 支持 HMI 交互,可手动清除累计值
// 5. 代码结构清晰,注释详细,易于维护和扩展
// ===============================================================