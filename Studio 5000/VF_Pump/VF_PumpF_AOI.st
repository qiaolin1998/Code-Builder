HMI_CMD.Fan1_Remote := Fan1_Remote; // 1#风机远程信号映射到HMI
HMI_CMD.Fan1_Run := Fan1_Run;       // 1#风机运行反馈映射到HMI
HMI_CMD.Fan2_Remote := Fan2_Remote; // 2#风机远程信号映射到HMI
HMI_CMD.Fan2_Run := Fan2_Run;       // 2#风机运行反馈映射到HMI
HMI_CMD.Fan3_Remote := Fan3_Remote; // 3#风机远程信号映射到HMI
HMI_CMD.Fan3_Run := Fan3_Run;       // 3#风机运行反馈映射到HMI
HMI_CMD.VF_Power := VF_Power;       // 变频器电源状态映射
HMI_CMD.VF_Remote := VF_Remote;     // 变频器远程信号映射
HMI_CMD.VF_Run := VF_Run;           // 变频器运行反馈映射
HMI_CMD.VF_Fault := VF_Fault;       // 变频器故障信号映射
HMI_CMD.Current := Current;         // 变频器电流反馈映射
HMI_CMD.VF_PV := VF_PV;             // 变频器频率反馈值映射
VF_SP := HMI_CMD.VF_SP;             // 变频器频率设定值从HMI读取

// 启动条件: (HMI启动且无联锁) 或 (HMI/外部启动且联锁且满足联锁条件)，并且无故障
Start_Contion :=((HMI_CMD.PB_Start and not HMI_CMD.VF_Lock) or ((HMI_CMD.PB_Start or Ext_Start) and HMI_CMD.VF_Lock and VF_Lock_Start_Contion)) and NOT VF_Fault;

// 停止条件: (HMI停止且无联锁) 或 (HMI/外部停止且联锁且满足联锁条件) 或 发生故障
Stop_Contion := (HMI_CMD.PB_Stop and not HMI_CMD.VF_Lock) or ((HMI_CMD.PB_Stop or Ext_Stop) and HMI_CMD.VF_Lock and VF_Lock_Stop_Contion) or VF_Fault;

// 1#风机控制逻辑
Out_Fan1_Op := (Out_Fan1_Op or Start_Contion) and Fan1_Remote and not Fan1_Run and not TonR_01.DN; // 1#风机双点启动: 启动条件满足，远程就绪，未运行，启动脉冲未完成
TonR_01.PRE :=1000;
TonR_01.TimerEnable :=Out_Fan1_Op;
TONR(TonR_01); // 1#风机启动脉冲计时 1s

Out_Fan1_Ot := (Out_Fan1_Ot or Stop_Contion) and Fan1_Remote and not TonR_10.DN; // 1#风机双点停止: 停止条件满足，远程就绪，停止脉冲未完成
TonR_10.PRE :=1000;
TonR_10.TimerEnable :=Out_Fan1_Ot;
TONR(TonR_10); // 1#风机停止脉冲计时 1s

Out_Fan1_Opt := (Out_Fan1_Opt or Out_Fan1_Op) and not Out_Fan1_Ot; // 1#风机单点启停信号保持

// 2#风机控制逻辑 (延时启动)
Temp[0] := (Temp[0] or Start_Contion) and not TonR_02.DN; // 启动信号保持，等待延时
TonR_02.PRE :=3000;
TonR_02.TimerEnable :=Temp[0];
TONR(TonR_02); // 2#风机启动延时 3s

Out_Fan2_Op := (Out_Fan2_Op or TonR_02.DN) and Fan2_Remote and not Fan2_Run and not TonR_03.DN; // 2#风机双点启动: 延时完成，远程就绪，未运行
TonR_03.PRE :=1000;
TonR_03.TimerEnable :=Out_Fan2_Op;
TONR(TonR_03); // 2#风机启动脉冲计时 1s

Out_Fan2_Ot := (Out_Fan2_Ot or Stop_Contion) and Fan2_Remote and not TonR_11.DN; // 2#风机双点停止
TonR_11.PRE :=1000;
TonR_11.TimerEnable :=Out_Fan2_Ot;
TONR(TonR_11); // 2#风机停止脉冲计时 1s

Out_Fan2_Opt := (Out_Fan2_Opt or Out_Fan2_Op) and not Out_Fan2_Ot; // 2#风机单点启停信号保持

// 3#风机控制逻辑 (延时启动)
Temp[1] := (Temp[1] or Start_Contion) and not TonR_04.DN; // 启动信号保持，等待延时
TonR_04.PRE :=6000;
TonR_04.TimerEnable :=Temp[1];
TONR(TonR_04); // 3#风机启动延时 6s

Out_Fan3_Op := (Out_Fan3_Op or TonR_04.DN) and Fan3_Remote and not Fan3_Run and not TonR_09.DN; // 3#风机双点启动: 延时完成，远程就绪，未运行
TonR_09.PRE :=1000;
TonR_09.TimerEnable :=Out_Fan3_Op;
TONR(TonR_09); // 3#风机启动脉冲计时 1s

Out_Fan3_Ot := (Out_Fan3_Ot or Stop_Contion) and Fan3_Remote and not TonR_12.DN; // 3#风机双点停止
TonR_12.PRE :=1000;
TonR_12.TimerEnable :=Out_Fan3_Ot;
TONR(TonR_12); // 3#风机停止脉冲计时 1s

Out_Fan3_Opt := (Out_Fan3_Opt or Out_Fan3_Op) and not Out_Fan3_Ot; // 3#风机单点启停信号保持

// 变频器控制逻辑
Temp[3] := Fan1_Run and Fan2_Run and Fan3_Run; // 所有风机运行状态确认

Temp[4] := (Temp[4] or Temp[3]) and not TonR_13.DN and not VF_Run; // 变频器启动前延时条件
TonR_13.PRE :=3000;
TonR_13.TimerEnable :=Temp[4];
TONR(TonR_13); // 变频器启动前延时 3s

Temp1[7] := (Temp[3] and Start_Contion) or TonR_13.DN; // 变频器启动信号生成

Temp1[0]:= VF_Power and VF_Remote and Temp[3] and Temp1[7]; // 变频器启动综合条件: 电源正常，远程，风机运行，启动信号
Temp1[10]:= (Temp1[0] or Temp1[10]) and not TonR_05.DN and not VF_Fault and not HMI_CMD.Err_VF_OTime and not HMI_CMD.PB_Stop; // 启动保持
TonR_05.PRE :=3000;
TonR_05.TimerEnable :=Temp1[10];
TONR(TonR_05); // 变频器启动脉冲计时 3s

Out_VF_Ot := Temp1[10]; // 变频器双点启动输出
Out_VF_Otp := (Out_VF_Ot or Out_VF_Otp) and not Out_VF_Op; // 变频器单点启停信号

Temp1[2] := VF_Power and VF_Remote and (Stop_Contion or HMI_CMD.Err_VF_OTime); // 变频器停止条件
Temp1[3]:= (Temp1[2] or Temp1[3]) and not TonR_06.DN; // 停止保持
TonR_06.PRE :=3000;
TonR_06.TimerEnable :=Temp1[3];
TONR(TonR_06); // 变频器停止脉冲计时 3s

Out_VF_Op := Temp1[3]; // 变频器双点停止输出

// 变频器复位逻辑
Temp1[6] := (HMI_CMD.PB_Reset or Temp1[6]) and not TonR_08.DN;
TonR_08.PRE :=3000;
TonR_08.TimerEnable :=Temp1[6];
TONR(TonR_08); // 复位脉冲计时 3s
Out_VF_Reset := Temp1[6]; // 变频器复位输出

// 超时故障检测
Temp1[4] := (Temp1[0] or Temp1[4]) and not VF_Run and not HMI_CMD.PB_Reset1; // 启动超时计时条件: 启动指令发出但未运行
Temp1[5] := (Temp1[2] or Temp1[5]) and VF_Run and not HMI_CMD.PB_Reset1; // 停止超时计时条件: 停止指令发出但仍在运行

TonR_07.PRE :=HMI_CMD.T_VF_OTime * 1000; // 设置超时时间
TonR_07.TimerEnable :=Temp1[4] or Temp1[5]; // 启用超时定时器
TONR(TonR_07); // 超时检测定时器

if TonR_07.DN then
	HMI_CMD.Err_VF_OTime :=1; // 置位超时故障
end_if;

if HMI_CMD.PB_Reset1 then
	HMI_CMD.Err_VF_OTime :=0; // 复位超时故障
end_if;

Out_VF_Stop := not VF_Run; // 变频器停止状态指示

// 运行时间统计
OSFI_VF_Run.InputBit := VF_Run;
OSFI(OSFI_VF_Run); // 运行信号下降沿检测 (停止瞬间)
OSRI_VF_Run.InputBit := VF_Run;
OSRI(OSRI_VF_Run); // 运行信号上升沿检测 (启动瞬间)

RTOR_VF_Run.PRE := 2147483647;
RTOR_VF_Run.Reset := OSFI_VF_Run.OutputBit; // 运行停止时复位单次运行时间
RTOR_VF_Run.TimerEnable := VF_Run;
Temp_Time[0] := RTOR_VF_Run.ACC / 1000; // 计算单次运行时间(秒)
RTOR(RTOR_VF_Run); // 单次运行时间计时器

HMI_CMD.Day := Temp_Time[0] / 86400; // 单次运行时间-天
Temp_Time[1] := Temp_Time[0] MOD 86400;
HMI_CMD.Hour := Temp_Time[1] / 3600; // 单次运行时间-小时
Temp_Time[2] := Temp_Time[0] MOD 3600;
HMI_CMD.Minute := Temp_Time[2] / 60; // 单次运行时间-分
HMI_CMD.Second := Temp_Time[0] MOD 60; // 单次运行时间-秒

RTOR_VF_Run_Acc.PRE := 2147483647;
RTOR_VF_Run_Acc.Reset := HMI_CMD.PB_Clear; // 清除累计运行时间
RTOR_VF_Run_Acc.TimerEnable := VF_Run;
Temp_Time[3] := RTOR_VF_Run_Acc.ACC / 1000; // 计算累计运行时间(秒)
RTOR(RTOR_VF_Run_Acc); // 累计运行时间计时器

HMI_CMD.Acc_Day := Temp_Time[3] / 86400; // 累计运行时间-天
Temp_Time[4] := Temp_Time[3] MOD 86400;
HMI_CMD.Acc_Hour := Temp_Time[4] / 3600; // 累计运行时间-小时
Temp_Time[5] := Temp_Time[3] MOD 3600;
HMI_CMD.Acc_Minute := Temp_Time[5] / 60; // 累计运行时间-分
HMI_CMD.Acc_Second := Temp_Time[3] MOD 60; // 累计运行时间-秒
