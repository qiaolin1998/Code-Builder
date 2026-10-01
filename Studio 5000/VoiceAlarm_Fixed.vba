'=====================================================================
' 固定数值判断报警示例
' 功能：监控数值显示控件的变化，当数值超过或低于固定阈值时进行语音报警
' 实现原理：比较当前值与预设的固定上下限值，当数值跨越阈值时触发语音报警
'=====================================================================

'=====================================================================
' NumericDisplay10_Change 事件处理过程
' 功能：监控10号数值显示控件，当数值超过上限或低于下限时进行语音报警
' 说明：
'   - 上限阈值：5.0（固定数值）
'   - 下限阈值：3.5（固定数值）
'   - 使用静态变量prevValue避免数值在阈值附近波动时重复报警
'=====================================================================
Private Sub NumericDisplay10_Change()
    ' 声明静态变量用于保存前一个值，避免重复报警
    ' Static关键字使得该变量在过程结束后仍然保留其值，用于比较数值变化
    Static prevValue As Variant
    
    ' 声明语音对象变量，用于调用Windows SAPI语音合成功能
    Dim sapi As Object
    
    ' 声明循环计数器，用于控制语音播放次数
    Dim i As Integer
    
    ' 声明上限值变量（固定数值，单位根据实际应用确定）
    Dim upperLimit As Double
    
    ' 声明下限值变量（固定数值，单位根据实际应用确定）
    Dim lowerLimit As Double
    
    ' 声明当前值变量，用于存储从控件读取的数值
    Dim currentValue As Double
    
    ' 设置固定的上限阈值
    upperLimit = 5.0
    
    ' 设置固定的下限阈值
    lowerLimit = 3.5
    
    ' 检查NumericDisplay10控件的值是否为有效的数字
    ' IsNumeric函数用于判断值是否可以转换为数字
    If IsNumeric(NumericDisplay10.Value) Then
        ' 将控件值转换为双精度浮点数并赋给currentValue
        ' CDbl函数将变体或字符串转换为双精度浮点数
        currentValue = CDbl(NumericDisplay10.Value)
    Else
        ' 如果控件值不是有效数字，设置默认值为0
        ' 这样可以避免类型转换错误
        currentValue = 0
    End If
    
    ' 创建语音对象实例
    ' SAPI.SpVoice是Windows自带的语音合成对象
    ' CreateObject用于创建COM对象实例
    Set sapi = CreateObject("SAPI.SpVoice")
    
    ' 判断当前值是否超过上限
    ' 条件说明：
    '   1. currentValue > upperLimit：当前值大于上限
    '   2. IsEmpty(prevValue) Or prevValue <= upperLimit：前一个值不存在或前一个值小于等于上限
    '   第二个条件确保只在数值首次跨越上限时触发报警，避免重复报警
    If currentValue > upperLimit And (IsEmpty(prevValue) Or prevValue <= upperLimit) Then
        ' 循环2次播放报警语音，加强提醒效果
        For i = 1 To 2
            ' 调用语音合成对象的Speak方法播放语音
            ' & 运算符用于连接字符串和变量值
            sapi.Speak "数值超过" & upperLimit
        Next i
    End If
    
    ' 判断当前值是否低于下限
    ' 条件说明：
    '   1. currentValue < lowerLimit：当前值小于下限
    '   2. IsEmpty(prevValue) Or prevValue >= lowerLimit：前一个值不存在或前一个值大于等于下限
    '   第二个条件确保只在数值首次跨越下限时触发报警，避免重复报警
    If currentValue < lowerLimit And (IsEmpty(prevValue) Or prevValue >= lowerLimit) Then
        ' 循环2次播放报警语音，加强提醒效果
        For i = 1 To 2
            ' 调用语音合成对象的Speak方法播放语音
            sapi.Speak "数值低于" & lowerLimit
        Next i
    End If
    
    ' 保存当前值作为下一次比较的前值
    ' 这样在下次事件触发时可以判断数值是否跨越阈值
    prevValue = currentValue
    
    ' 释放语音对象，释放系统资源
    ' 将对象变量设置为Nothing是一种良好的编程习惯
    Set sapi = Nothing
End Sub

'=====================================================================
' NumericDisplay11_Change 事件处理过程
' 功能：监控11号数值显示控件，当数值超过上限或低于下限时进行语音报警
' 说明：
'   - 上限阈值：10.0（固定数值）
'   - 下限阈值：2.0（固定数值）
'   - 使用静态变量prevValue避免数值在阈值附近波动时重复报警
'=====================================================================
Private Sub NumericDisplay11_Change()
    ' 声明静态变量用于保存前一个值，避免重复报警
    Static prevValue As Variant
    
    ' 声明语音对象变量，用于调用Windows SAPI语音合成功能
    Dim sapi As Object
    
    ' 声明循环计数器，用于控制语音播放次数
    Dim i As Integer
    
    ' 声明上限值变量（固定数值，单位根据实际应用确定）
    Dim upperLimit As Double
    
    ' 声明下限值变量（固定数值，单位根据实际应用确定）
    Dim lowerLimit As Double
    
    ' 声明当前值变量，用于存储从控件读取的数值
    Dim currentValue As Double
    
    ' 设置固定的上限阈值
    upperLimit = 10.0
    
    ' 设置固定的下限阈值
    lowerLimit = 2.0
    
    ' 检查NumericDisplay11控件的值是否为有效的数字
    If IsNumeric(NumericDisplay11.Value) Then
        ' 将控件值转换为双精度浮点数并赋给currentValue
        currentValue = CDbl(NumericDisplay11.Value)
    Else
        ' 如果控件值不是有效数字，设置默认值为0
        currentValue = 0
    End If
    
    ' 创建语音对象实例
    Set sapi = CreateObject("SAPI.SpVoice")
    
    ' 判断当前值是否超过上限
    ' 条件说明：
    '   1. currentValue > upperLimit：当前值大于上限
    '   2. IsEmpty(prevValue) Or prevValue <= upperLimit：前一个值不存在或前一个值小于等于上限
    '   第二个条件确保只在数值首次跨越上限时触发报警，避免重复报警
    If currentValue > upperLimit And (IsEmpty(prevValue) Or prevValue <= upperLimit) Then
        ' 循环2次播放报警语音，加强提醒效果
        For i = 1 To 2
            ' 调用语音合成对象的Speak方法播放语音
            sapi.Speak "数值超过" & upperLimit
        Next i
    End If
    
    ' 判断当前值是否低于下限
    ' 条件说明：
    '   1. currentValue < lowerLimit：当前值小于下限
    '   2. IsEmpty(prevValue) Or prevValue >= lowerLimit：前一个值不存在或前一个值大于等于下限
    '   第二个条件确保只在数值首次跨越下限时触发报警，避免重复报警
    If currentValue < lowerLimit And (IsEmpty(prevValue) Or prevValue >= lowerLimit) Then
        ' 循环2次播放报警语音，加强提醒效果
        For i = 1 To 2
            ' 调用语音合成对象的Speak方法播放语音
            sapi.Speak "数值低于" & lowerLimit
        Next i
    End If
    
    ' 保存当前值作为下一次比较的前值
    prevValue = currentValue
    
    ' 释放语音对象，释放系统资源
    Set sapi = Nothing
End Sub
