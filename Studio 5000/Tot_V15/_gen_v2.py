# -*- coding: utf-8 -*-
import xml.etree.ElementTree as ET
# 将 st 原封不动嵌到 CDATA 里, 避免任何解析问题
with open(r"e:\华为家庭存储\Project\Obsidian\Code Builder\Studio 5000\Tot_V15\TempAlarm16_L2.st","rb") as f:
    st_content = f.read().decode("utf-8")
st_lines = st_content.splitlines()

def line(s=""): print(s)

def marr(name, dt, dim, radix, desc):
    line(f'<Member Name="{name}" DataType="{dt}" Dimension="{dim}" Radix="{radix}" Hidden="false" ExternalAccess="Read/Write">')
    line("<Description>")
    line(f"<![CDATA[{desc}]]>")
    line("</Description></Member>")

def pb(n, u, d):
    line(f'<Parameter Name="{n}" TagType="Base" DataType="BOOL" Usage="{u}" Radix="Decimal" Required="false" Visible="false" ExternalAccess="Read Only">')
    line("<Description>"); line(f"<![CDATA[{d}]]>"); line("</Description>")
    line('<DefaultData Format="L5K"><![CDATA[0]]></DefaultData>')
    line('<DefaultData Format="Decorated"><DataValue DataType="BOOL" Radix="Decimal" Value="0"/></DefaultData></Parameter>')

def pd(n, d):
    line(f'<Parameter Name="{n}" TagType="Base" DataType="DINT" Usage="Input" Radix="Decimal" Required="false" Visible="false" ExternalAccess="Read/Write">')
    line("<Description>"); line(f"<![CDATA[{d}]]>"); line("</Description>")
    line('<DefaultData Format="L5K"><![CDATA[0]]></DefaultData>')
    line('<DefaultData Format="Decorated"><DataValue DataType="DINT" Radix="Decimal" Value="0"/></DefaultData></Parameter>')

def ls(n, t, d):
    line(f'<LocalTag Name="{n}" DataType="{t}" Radix="Decimal" ExternalAccess="None">')
    line("<Description>"); line(f"<![CDATA[{d}]]>"); line("</Description></LocalTag>")

print('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
print('<RSLogix5000Content SchemaRevision="1.0" SoftwareRevision="36.00" TargetName="TempAlarm16_L2" TargetType="AddOnInstructionDefinition" TargetRevision="2.0" TargetLastEdited="2026-10-22T00:00:00.000Z" ContainsContext="true" ExportDate="Thu Oct 22 00:00:00 2026" ExportOptions="References NoRawData L5KData DecoratedData Context Dependencies ForceProtectedEncoding AllProjDocTrans">')
print('<Controller Use="Context" Name="TempAlarm16_L2">')
print('<DataTypes Use="Context">')

# --- Config UDT ---
print('<DataType Name="TempAlarm16_L2_Cfg_Type" Family="NoFamily" Class="User"><Members>')
marr('SP1','REAL',16,'Float','L1 threshold (Input, MOVable by external program)')
marr('SP2','REAL',16,'Float','L2 threshold (SP2>0 means configured; <=0 uses defaults)')
marr('Hys','REAL',16,'Float','Hysteresis (release = SP - Hys)')
marr('Dly1','DINT',16,'Decimal','L1 debounce delay (seconds)')
marr('Dly2','DINT',16,'Decimal','L2 debounce delay (seconds)')
marr('Enable','BOOL',16,'Decimal','Channel enable (1=on 0=off)')
marr('Name','STRING',16,'NullType','Channel tag name (event log snapshot source)')
print('</Members></DataType>')

# --- Runtime State UDT ---
print('<DataType Name="TempAlarm16_L2_Type" Family="NoFamily" Class="User"><Members>')
print('<Member Name="ZZZZZZZZZZTempAlarm16_L20" DataType="SINT" Dimension="0" Radix="Decimal" Hidden="true" ExternalAccess="Read/Write"/>')
for n, b, d in [('Apply_Batch',0,'Batch apply command (pulse, HMI writes)'),
                ('Reset_Log',1,'Clear event log command (pulse)'),
                ('Ack_Alm2',2,'Acknowledge L2 alarms')]:
    print(f'<Member Name="{n}" DataType="BIT" Dimension="0" Radix="Decimal" Hidden="false" Target="ZZZZZZZZZZTempAlarm16_L20" BitNumber="{b}" ExternalAccess="Read/Write"><Description><![CDATA[{d}]]></Description></Member>')
# 生效配置镜像
marr('Eff_SP1','REAL',16,'Float','Effective L1 threshold (mirror of In_Cfg; falls back to defaults)')
marr('Eff_SP2','REAL',16,'Float','Effective L2 threshold')
marr('Eff_Hys','REAL',16,'Float','Effective hysteresis')
marr('Eff_Dly1','DINT',16,'Decimal','Effective L1 delay (s)')
marr('Eff_Dly2','DINT',16,'Decimal','Effective L2 delay (s)')
marr('Eff_Enable','BOOL',16,'Decimal','Effective enable')
marr('Eff_Name','STRING',16,'NullType','Effective channel tag name')
# 运行时状态
marr('Sta_Alm1','BOOL',16,'Decimal','L1 alarm status')
marr('Sta_Alm2','BOOL',16,'Decimal','L2 alarm status')
marr('Alm2_UnAck','BOOL',16,'Decimal','L2 unacknowledged latch (drives popup + horn)')
# 内部工作数组
marr('Acc1','DINT',16,'Decimal','Internal - L1 debounce sec counter')
marr('Acc2','DINT',16,'Decimal','Internal - L2 debounce sec counter')
marr('PrevAlm1','BOOL',16,'Decimal','Internal - L1 edge prev cycle')
marr('PrevAlm2','BOOL',16,'Decimal','Internal - L2 edge prev cycle')
# 汇总标志
for n,d in [('Any_Alm1','Any L1 alarm total flag'),('Any_Alm2','Any L2 alarm total flag'),('Any_Alm2_UnAck','Any L2 unacknowledged total'),('Alm1_Count','L1 alarm count'),('Alm2_Count','L2 alarm count'),('User_Level','Operator privilege (>=2 allows batch)')]:
    marr(n,'DINT' if n.endswith('Count') or n=='User_Level' else 'BOOL',0,'Decimal',d)
# 批量下发源参数
for n,d in [('B_Group','Batch target group (0=all 1=stator 2=motor brg 3=pump brg 4=gear oil)'),('B_SP1','Batch L1 threshold'),('B_SP2','Batch L2 threshold'),('B_Hys','Batch hysteresis'),('B_Dly1','Batch L1 delay (s)'),('B_Dly2','Batch L2 delay (s)')]:
    if n in ('B_SP1','B_SP2','B_Hys'):
        marr(n,'REAL',0,'Float',d)
    else:
        marr(n,'DINT',0,'Decimal',d)
# 事件缓冲
marr('Evt_Head','DINT',0,'Decimal','Event ring buffer write pointer (0..31)')
marr('Evt_Ch','DINT',32,'Decimal','Event channel number')
marr('Evt_ChName','STRING',32,'NullType','Event channel tag name snapshot')
marr('Evt_Type','DINT',32,'Decimal','Event type (1=L1on 2=L1off 3=L2on 4=L2off 5=batch cfg 6=denied)')
marr('Evt_PV','REAL',32,'Float','PV at event')
marr('Evt_H','DINT',32,'Decimal','Event timestamp - hour')
marr('Evt_M','DINT',32,'Decimal','Event timestamp - min')
marr('Evt_S','DINT',32,'Decimal','Event timestamp - sec')
print('</Members></DataType>')
print('</DataTypes>')

# --- AOI ---
print('<AddOnInstructionDefinitions Use="Context">')
print('<AddOnInstructionDefinition Use="Target" Name="TempAlarm16_L2" Revision="2.0" ExecutePrescan="false" ExecutePostscan="false" ExecuteEnableInFalse="false" CreatedDate="2026-10-20T00:00:00.000Z" CreatedBy="Trae" EditedDate="2026-10-22T00:00:00.000Z" EditedBy="Trae" SoftwareRevision="v36.00">')
print('<Parameters>')
pb('EnableIn','Input','Enable input')
pb('EnableOut','Output','Enable output')
pd('Hour','Clock hour (event log)')
pd('Minute','Clock minute (event log)')
pd('Second','Clock second (event log + debounce tick)')
print('<Parameter Name="PV" TagType="Base" DataType="REAL" Dimension="16" Usage="Input" Radix="Float" Required="false" Visible="false" ExternalAccess="Read/Write"><Description><![CDATA[16x PV input (PV[0]..PV[15])]]></Description></Parameter>')
print('<Parameter Name="In_Cfg" TagType="Base" DataType="TempAlarm16_L2_Cfg_Type" Usage="Input" Required="false" Visible="true" Constant="false"><Description><![CDATA[Input config UDT: SP1/SP2/Hys/Dly1/Dly2/Enable/Name[16] - external programs MOV these to change thresholds]]></Description></Parameter>')
pb('Out_Warn','Output','L1 total output (non-forced banner)')
pb('Out_Trip','Output','L2 total output (shutdown trip)')
pb('Out_Horn','Output','Horn (any L2 unacknowledged)')
print('<Parameter Name="HMI_CMD" TagType="Base" DataType="TempAlarm16_L2_Type" Usage="InOut" Required="true" Visible="true" Constant="false"><Description><![CDATA[Runtime state: Eff_* mirror / Sta_* / Alm2_UnAck / event ring buffer / B_* batch source params / Apply_Batch/Reset_Log/Ack_Alm2]]></Description></Parameter>')
print('</Parameters>')

# LocalTags - 仅原子标量, 无 DefaultData, 无 Dimension
print('<LocalTags>')
for n,t,d in [('Tick','BOOL','1s tick (Second changes)'),('Prev_Second','DINT','Previous Second value'),('i','DINT','FOR loop index'),('GS','DINT','Batch start channel idx'),('GE','DINT','Batch end channel idx'),('IsFirstScan','BOOL','First scan flag')]:
    ls(n,t,d)
print('</LocalTags>')

# Routine
print('<Routines><Routine Name="Logic" Type="ST"><STContent>')
for k,l in enumerate(st_lines):
    print(f'<Line Number="{k}"><![CDATA[{l}]]></Line>')
print('</STContent></Routine></Routines>')
print('<Dependencies><Dependency Type="DataType" Name="TempAlarm16_L2_Cfg_Type"/><Dependency Type="DataType" Name="TempAlarm16_L2_Type"/></Dependencies>')
print('</AddOnInstructionDefinition></AddOnInstructionDefinitions></Controller></RSLogix5000Content>')
