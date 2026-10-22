$ErrorActionPreference='Stop'
$dir='e:\华为家庭存储\Project\Obsidian\Code Builder\Studio 5000\Tot_V15'
$l5x=Join-Path $dir 'TempAlarm16_L2_AOI.L5X'
$stp=Join-Path $dir 'TempAlarm16_L2.st'
$st=Get-Content -LiteralPath $stp -Encoding UTF8

$L=New-Object System.Collections.Generic.List[string]
function A([string]$s){ $L.Add($s) | Out-Null }

A '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
A '<RSLogix5000Content SchemaRevision="1.0" SoftwareRevision="36.00" TargetName="TempAlarm16_L2" TargetType="AddOnInstructionDefinition" TargetRevision="2.0 " TargetLastEdited="2026-10-22T00:00:00.000Z" ContainsContext="true" ExportDate="Thu Oct 22 00:00:00 2026" ExportOptions="References NoRawData L5KData DecoratedData Context Dependencies ForceProtectedEncoding AllProjDocTrans">'
A '<Controller Use="Context" Name="TempAlarm16_L2">'
A '<DataTypes Use="Context">'

function MArr([string]$name,[string]$dt,[int]$dim,[string]$radix,[string]$desc){
  A ('<Member Name="'+$name+'" DataType="'+$dt+'" Dimension="'+$dim+'" Radix="'+$radix+'" Hidden="false" ExternalAccess="Read/Write">')
  A '<Description>'; A ('<![CDATA['+$desc+']]>'); A '</Description>'; A '</Member>'
}

A '<!-- 输入配置 UDT: 调用方通过 In_Cfg 接线传入全部可配置参数 -->'
A '<DataType Name="TempAlarm16_L2_Cfg_Type" Family="NoFamily" Class="User">'
A '<Members>'
MArr 'SP1'    'REAL'   16 'Float'    '一级报警阈值(由外部程序/MOV 直接修改)'
MArr 'SP2'    'REAL'   16 'Float'    '二级报警阈值(SP2>0 表示该通道已配置)'
MArr 'Hys'    'REAL'   16 'Float'    '回差值(解除阈值=SP-Hys)'
MArr 'Dly1'   'DINT'   16 'Decimal'  '一级报警防抖延时(秒)'
MArr 'Dly2'   'DINT'   16 'Decimal'  '二级报警防抖延时(秒)'
MArr 'Enable' 'BOOL'   16 'Decimal'  '各通道使能(1=投入 0=退出)'
MArr 'Name'   'STRING' 16 'NullType' '测点标识名(事件记录快照源)'
A '</Members>'
A '</DataType>'

A '<!-- 运行时状态 UDT: 全部由 AOI 内部维护, HMI 只读监控 + 少量命令可写 -->'
A '<DataType Name="TempAlarm16_L2_Type" Family="NoFamily" Class="User">'
A '<Members>'
A '<Member Name="ZZZZZZZZZZTempAlarm16_L20" DataType="SINT" Dimension="0" Radix="Decimal" Hidden="true" ExternalAccess="Read/Write"/>'
A '<Member Name="Apply_Batch" DataType="BIT" Dimension="0" Radix="Decimal" Hidden="false" Target="ZZZZZZZZZZTempAlarm16_L20" BitNumber="0" ExternalAccess="Read/Write"><Description><![CDATA[批量参数写入命令(点动置位)]]></Description></Member>'
A '<Member Name="Reset_Log"   DataType="BIT" Dimension="0" Radix="Decimal" Hidden="false" Target="ZZZZZZZZZZTempAlarm16_L20" BitNumber="1" ExternalAccess="Read/Write"><Description><![CDATA[清空事件记录命令(点动置位)]]></Description></Member>'
A '<Member Name="Ack_Alm2"    DataType="BIT" Dimension="0" Radix="Decimal" Hidden="false" Target="ZZZZZZZZZZTempAlarm16_L20" BitNumber="2" ExternalAccess="Read/Write"><Description><![CDATA[二级报警确认命令]]></Description></Member>'
# 生效配置镜像(与 Input 参数同步, 零值通道自动填默认值)
MArr 'Eff_SP1'    'REAL'   16 'Float'   '生效配置-一级阈值(Input>0 时=Input, 否则=默认值)'
MArr 'Eff_SP2'    'REAL'   16 'Float'   '生效配置-二级阈值'
MArr 'Eff_Hys'    'REAL'   16 'Float'   '生效配置-回差'
MArr 'Eff_Dly1'   'DINT'   16 'Decimal' '生效配置-一级延时(秒)'
MArr 'Eff_Dly2'   'DINT'   16 'Decimal' '生效配置-二级延时(秒)'
MArr 'Eff_Enable' 'BOOL'   16 'Decimal' '生效配置-使能'
MArr 'Eff_Name'   'STRING' 16 'NullType' '生效配置-测点标识名'
# 运行时状态
MArr 'Sta_Alm1'   'BOOL'   16 'Decimal' '一级报警状态'
MArr 'Sta_Alm2'   'BOOL'   16 'Decimal' '二级报警状态'
MArr 'Alm2_UnAck' 'BOOL'   16 'Decimal' '二级报警未确认锁存'
# 内部工作数组
MArr 'Acc1'       'DINT'   16 'Decimal' '内部-一级防抖秒计数'
MArr 'Acc2'       'DINT'   16 'Decimal' '内部-二级防抖秒计数'
MArr 'PrevAlm1'   'BOOL'   16 'Decimal' '内部-一级边沿检测上一周期值'
MArr 'PrevAlm2'   'BOOL'   16 'Decimal' '内部-二级边沿检测上一周期值'
# 汇总标志
MArr 'Any_Alm1'         'BOOL'  0 'Decimal' '任一路一级报警总标志'
MArr 'Any_Alm2'         'BOOL'  0 'Decimal' '任一路二级报警总标志'
MArr 'Any_Alm2_UnAck'   'BOOL'  0 'Decimal' '任一二级报警未确认总标志'
MArr 'Alm1_Count'       'DINT'  0 'Decimal' '当前一级报警通道数'
MArr 'Alm2_Count'       'DINT'  0 'Decimal' '当前二级报警通道数'
# 批量下发源参数(HMI 填值后 Apply_Batch 生效)
MArr 'User_Level'    'DINT'  0 'Decimal' '当前操作员权限等级(>=2 允许批量下发)'
MArr 'B_Group'       'DINT'  0 'Decimal' '批量目标组(0=全部 1=定子 2=电机轴承 3=泵轴承 4=减速机油)'
MArr 'B_SP1'         'REAL'  0 'Float'   '批量下发: 一级阈值'
MArr 'B_SP2'         'REAL'  0 'Float'   '批量下发: 二级阈值'
MArr 'B_Hys'         'REAL'  0 'Float'   '批量下发: 回差值'
MArr 'B_Dly1'        'DINT'  0 'Decimal' '批量下发: 一级延时(秒)'
MArr 'B_Dly2'        'DINT'  0 'Decimal' '批量下发: 二级延时(秒)'
# 事件环形缓冲
MArr 'Evt_Head'      'DINT'   0  'Decimal'  '事件环形缓冲写指针(0..31)'
MArr 'Evt_Ch'        'DINT'   32 'Decimal'  '事件通道号'
MArr 'Evt_ChName'    'STRING' 32 'NullType' '事件测点标识名快照'
MArr 'Evt_Type'      'DINT'   32 'Decimal'  '事件类型(1一级产生 2一级解除 3二级产生 4二级解除 5参数修改 6越权)'
MArr 'Evt_PV'        'REAL'   32 'Float'    '事件当时 PV'
MArr 'Evt_H'         'DINT'   32 'Decimal'  '事件时标-时'
MArr 'Evt_M'         'DINT'   32 'Decimal'  '事件时标-分'
MArr 'Evt_S'         'DINT'   32 'Decimal'  '事件时标-秒'
A '</Members>'
A '</DataType>'
A '</DataTypes>'

A '<AddOnInstructionDefinitions Use="Context">'
A '<AddOnInstructionDefinition Use="Target" Name="TempAlarm16_L2" Revision="2.0" ExecutePrescan="false" ExecutePostscan="false" ExecuteEnableInFalse="false" CreatedDate="2026-10-20T00:00:00.000Z" CreatedBy="Trae" EditedDate="2026-10-22T00:00:00.000Z" EditedBy="Trae" SoftwareRevision="v36.00">'
A '<Parameters>'

function PB([string]$n,[string]$u,[string]$d){
  A ('<Parameter Name="'+$n+'" TagType="Base" DataType="BOOL" Usage="'+$u+'" Radix="Decimal" Required="false" Visible="false" ExternalAccess="Read Only"><Description><![CDATA['+$d+']]></Description><DefaultData Format="L5K"><![CDATA[0]]></DefaultData><DefaultData Format="Decorated"><DataValue DataType="BOOL" Radix="Decimal" Value="0"/></DefaultData></Parameter>')
}
function PI([string]$n,[string]$t,[string]$d){
  A ('<Parameter Name="'+$n+'" TagType="Base" DataType="'+$t+'" Usage="Input" Radix="Decimal" Required="false" Visible="false" ExternalAccess="Read/Write"><Description><![CDATA['+$d+']]></Description><DefaultData Format="L5K"><![CDATA[0]]></DefaultData><DefaultData Format="Decorated"><DataValue DataType="'+$t+'" Radix="Decimal" Value="0"/></DefaultData></Parameter>')
}
function PD([string]$n,[string]$d){ PI $n 'DINT' $d }

PB 'EnableIn'  'Input'  '使能输入'
PB 'EnableOut' 'Output' '使能输出'
PD 'Hour'   '系统时钟-时(事件记录时标)'
PD 'Minute' '系统时钟-分(事件记录时标)'
PD 'Second' '系统时钟-秒(事件记录时标 + 防抖秒节拍)'

# 16 路温度 Input 数组
A '<Parameter Name="PV" TagType="Base" DataType="REAL" Dimension="16" Usage="Input" Radix="Float" Required="false" Visible="false" ExternalAccess="Read/Write"><Description><![CDATA[16路实时温度(PV[0]..PV[15])]]></Description></Parameter>'

# 配置 Input 配置 UDT
A '<Parameter Name="In_Cfg" TagType="Base" DataType="TempAlarm16_L2_Cfg_Type" Usage="Input" Required="false" Visible="true" Constant="false"><Description><![CDATA[输入配置块: 阈值/回差/延时/使能/测点标识, 外部程序直接 MOV 修改]]></Description></Parameter>'

PB 'Out_Warn' 'Output' '一级报警总出口(非强制提示横幅)'
PB 'Out_Trip' 'Output' '二级报警总出口(停机联锁)'
PB 'Out_Horn' 'Output' '声响提醒(任一二级报警未确认时置位)'

A '<Parameter Name="HMI_CMD" TagType="Base" DataType="TempAlarm16_L2_Type" Usage="InOut" Required="true" Visible="true" Constant="false"><Description><![CDATA[运行时状态: 生效配置镜像/报警状态/事件缓冲/批量命令]]></Description></Parameter>'
A '</Parameters>'

# 本地变量(仅原子标量)
A '<LocalTags>'
function LS([string]$n,[string]$t,[string]$d){
  A ('<LocalTag Name="'+$n+'" DataType="'+$t+'" Radix="Decimal" ExternalAccess="None"><Description><![CDATA['+$d+']]></Description></LocalTag>')
}
LS 'Tick'         'BOOL' '秒节拍(Second 变化时=1)'
LS 'Prev_Second'  'DINT' '上一扫描周期的秒值'
LS 'i'            'DINT' 'FOR 循环索引'
LS 'GS'           'DINT' '批量写入起始通道下标'
LS 'GE'           'DINT' '批量写入结束通道下标'
LS 'IsFirstScan'  'BOOL' '首次扫描标志'
A '</LocalTags>'

A '<Routines>'
A '<Routine Name="Logic" Type="ST"><STContent>'
for($k=0;$k -lt $st.Count;$k++){
  A ('<Line Number="'+$k+'"><![CDATA['+$st[$k]+']]></Line>')
}
A '</STContent></Routine></Routines>'
A '<Dependencies><Dependency Type="DataType" Name="TempAlarm16_L2_Cfg_Type"/><Dependency Type="DataType" Name="TempAlarm16_L2_Type"/></Dependencies>'
A '</AddOnInstructionDefinition></AddOnInstructionDefinitions></Controller></RSLogix5000Content>'

[System.IO.File]::WriteAllText($l5x,($L -join "`n")+"`n",(New-Object System.Text.UTF8Encoding($false)))
$x=New-Object System.Xml.XmlDocument; $x.Load($l5x)
$Lc=@($x.SelectNodes('//LocalTags/LocalTag[@Dimension]')).Count
$Tm=@($x.SelectNodes('//LocalTags/LocalTag[@DataType="TIMER"]')).Count
Write-Output ("OK Params=$($x.SelectNodes('//Parameters/Parameter').Count) UDT_Members(运行时)=$($x.SelectNodes('//DataType[@Name="TempAlarm16_L2_Type"]/Members/Member').Count) UDT_Members(配置)=$($x.SelectNodes('//DataType[@Name="TempAlarm16_L2_Cfg_Type"]/Members/Member').Count) STLines=$($x.SelectNodes('//STContent/Line').Count) LocalTagDim=$Lc TimerTags=$Tm Bytes=$([System.IO.File]::ReadAllBytes($l5x).Length)")
