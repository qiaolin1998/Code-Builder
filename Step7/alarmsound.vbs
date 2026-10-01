' ==========================================================================
' 函数名: Action
' 功  能: WinCC VBS 脚本 —— 报警语音播报
'         配合 C 脚本 alarmsound.C 使用：
'           1. C 脚本检测到报警到来时，置位 "alarmComing" 并写入 "alarmText"
'           2. 本 VBS 脚本读取 "alarmComing"，若为1则通过 Windows SAPI
'              语音引擎朗读 "alarmText" 中的报警文本
'           3. 朗读完成后复位 "alarmComing"，防止重复播报
' 绑定方式: 通常绑定到 WinCC 画面对象的属性变化触发器或定时器事件
' ==========================================================================
Function Action()

    ' 声明变量
    Dim speaker, alarmText
    Dim alarmComing

    ' 读取 WinCC 变量 "alarmComing"（C 脚本置位的报警触发标志位）
    '   - 1: 有新报警到来，需要语音播报
    '   - 0: 无报警或已播报完毕
    alarmComing = HMIRuntime.Tags("alarmComing").Read

    ' 读取 WinCC 变量 "alarmText"（C 脚本写入的报警消息文本）
    '   该文本将被语音引擎朗读出来
    alarmText = HMIRuntime.Tags("alarmText").Read

    ' 判断是否有新报警需要播报
    If alarmComing = 1 Then

        ' 创建 Windows SAPI 语音对象 (Speech API)
        ' SAPI.SpVoice 是 Windows 系统自带的语音合成组件
        Set speaker = CreateObject("SAPI.SpVoice")

        ' 设置语速，范围 -10 ~ 10
        '   0 = 正常语速，负值变慢，正值变快
        speaker.Rate = 0

        ' 设置音量，范围 0 ~ 100
        '   100 = 最大音量
        speaker.Volume = 100

        ' 调用 Speak 方法朗读报警文本
        ' 该方法会阻塞执行，直到朗读完毕才返回
        speaker.Speak alarmText

        ' 朗读完成后复位 "alarmComing" 为 0
        ' 作用: 防止重复播报同一条报警
        '       下次 C 脚本置位时才会再次触发播报
        HMIRuntime.Tags("alarmComing").Write 0

    End If

End Function