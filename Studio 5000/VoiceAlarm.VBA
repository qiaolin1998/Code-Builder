' NumericDisplay1_Change 事件处理过程
' 功能：监控数值显示控件的变化，当数值超过上限或低于下限时进行语音报警
' 实现原理：比较当前值与预设的上下限值，当数值跨越阈值时触发语音报警
Private Sub NumericDisplay1_Change()
    ' 声明静态变量用于保存前一个值，避免重复报警
    Static prevValue As Variant
    ' 声明语音对象变量
    Dim sapi As Object
    ' 声明循环计数器
    Dim i As Integer
    ' 声明上限值变量
    Dim upperLimit As Double
    ' 声明下限值变量
    Dim lowerLimit As Double
    ' 声明当前值变量
    Dim currentValue As Double

    ' 检查NumericInput1的值是否为数字
    If IsNumeric(NumericInput1.Value) Then
        ' 将上限值转换为双精度浮点数
        upperLimit = CDbl(NumericInput1.Value)
    Else
        ' 设置默认上限值
        upperLimit = 5
    End If
    ' 检查NumericInput2的值是否为数字
    If IsNumeric(NumericInput2.Value) Then
        ' 将下限值转换为双精度浮点数
        lowerLimit = CDbl(NumericInput2.Value)
    Else
        ' 设置默认下限值
        lowerLimit = 3.5
    End If
    ' 检查NumericDisplay1的值是否为数字
    If IsNumeric(NumericDisplay1.Value) Then
        ' 将当前值转换为双精度浮点数
        currentValue = CDbl(NumericDisplay1.Value)
    Else
        ' 设置默认当前值
        currentValue = 0
    End If
    ' 创建语音对象实例
    Set sapi = CreateObject("SAPI.SpVoice")
    ' 检查当前值是否超过上限且是首次超过
    If currentValue > upperLimit And (IsEmpty(prevValue) Or prevValue <= upperLimit) Then
        ' 循环2次播放报警语音
        For i = 1 To 2
            ' 播放超过上限的报警语音
            sapi.Speak "实际值超过上限" & upperLimit & "报警"
        Next i
    End If
    ' 检查当前值是否低于下限且是首次低于
    If currentValue < lowerLimit And (IsEmpty(prevValue) Or prevValue >= lowerLimit) Then
        ' 循环2次播放报警语音
        For i = 1 To 2
            ' 播放低于下限的报警语音
            sapi.Speak "实际值低于下限" & lowerLimit & "报警"
        Next i
    End If
    ' 保存当前值作为下一次比较的前值
    prevValue = currentValue
    ' 释放语音对象
    Set sapi = Nothing
End Sub

