# OreProdStats_3Shift_Test AOI 使用说明

## 概述
这是一个用于测试 `OreProdStats_3Shift` AOI 的自动化测试系统。该测试AOI可以验证三班制产量统计系统的各项功能。

## 功能特点

### 测试模式
- **模式 0**: 基础功能测试
  - 脉冲累计功能验证
  - 清除功能验证
  - 使能控制验证

- **模式 1**: 班次切换测试
  - 早班 (09:00-17:00) 测试
  - 中班 (17:00-01:00) 测试  
  - 晚班 (01:00-09:00) 测试
  - 跨午夜班次切换验证

- **模式 2**: 2小时时段测试
  - 早班各时段累计验证
  - 时段切换逻辑测试
  - 产量分配正确性验证

- **模式 3**: 边界条件测试
  - 跨午夜处理测试
  - 月末/月初切换测试
  - 特殊时间点处理验证

## 参数说明

### 输入参数
- `EnableIn`: BOOL - 使能输入
- `Test_Mode`: DINT - 测试模式选择 (0-3)

### 输出参数
- `EnableOut`: BOOL - 使能输出
- `Test_Result`: TestResult_Type - 测试结果结构体

### TestResult_Type 结构体
```
Test_Passed: BOOL    - 测试通过标志
Test_Failed: BOOL    - 测试失败标志  
Test_Count: DINT     - 测试执行次数
Failed_Count: DINT   - 失败测试次数
Test_Message: STRING - 测试消息
```

## 使用方法

### 1. 基本配置
```
// 在程序中实例化测试AOI
OreProdStats_3Shift_Test_TestInstance(
    EnableIn := Test_Enable,
    Test_Mode := Test_Mode_Select,
    Test_Result := Test_Result_Data
);
```

### 2. 测试流程
1. 设置 `Test_Mode` 选择测试模式
2. 置位 `EnableIn` 开始测试
3. 监控 `Test_Result.Test_Message` 查看测试进度
4. 检查 `Test_Result.Test_Passed` 确认测试结果

### 3. 测试示例
```
// 基础功能测试
Test_Mode_Select := 0;
Test_Enable := TRUE;

// 等待测试完成
IF Test_Result_Data.Test_Passed THEN
    // 测试通过
    Display_Message := '基础功能测试通过';
ELSIF Test_Result_Data.Test_Failed THEN
    // 测试失败
    Display_Message := Test_Result_Data.Test_Message;
END_IF;
```

## 内部变量说明

### 模拟变量
- `Mock_Year/Month/Day/Hour/Minute/Second`: 模拟时间输入
- `Mock_Pulse`: 模拟脉冲信号
- `Mock_Run`: 模拟运行信号
- `Mock_Scale`: 模拟缩放系数 (默认100)
- `Mock_HMI_CMD`: 模拟HMI命令结构

### 测试控制
- `Test_Step`: 当前测试步骤
- `Test_Timer`: 测试定时器 (1秒间隔)
- `Expected_Value`: 预期测试值
- `Actual_Value`: 实际测试值

## 注意事项

### 1. 依赖关系
- 需要导入 `OreProdStats_3Shift_Type` 数据类型
- 需要导入 `OreProdStats_3Shift` AOI定义
- 使用了 `FBD_TIMER` 和 `FBD_ONESHOT` 指令

### 2. 实际使用建议
- 在实际使用时，需要在测试逻辑中实例化被测试的AOI
- 测试AOI提供了模拟输入，需要连接到实际AOI的输入参数
- 建议在非生产环境中进行测试

### 3. 扩展性
- 可以根据需要添加更多测试场景
- 支持自定义测试参数和预期值
- 可以扩展测试结果报告格式

## 测试结果解读

### 成功条件
- `Test_Result.Test_Passed = TRUE`
- `Test_Result.Failed_Count = 0`
- `Test_Result.Test_Message` 包含"通过"字样

### 失败处理
- 检查 `Test_Result.Failed_Count` 了解失败次数
- 查看 `Test_Result.Test_Message` 获取失败原因
- 根据消息内容定位具体问题

## 故障排除

### 常见问题
1. **测试不开始**: 检查 `EnableIn` 是否为TRUE
2. **测试卡住**: 检查测试定时器配置
3. **结果异常**: 验证模拟参数设置

### 调试建议
- 监控 `Test_Step` 了解测试进度
- 检查 `Test_Result.Test_Count` 确认测试执行
- 使用在线模式查看内部变量状态

## 版本信息
- 版本: 1.0
- 创建日期: 2026-02-24
- 兼容: Studio 5000 v36.00+
- 平台: ControlLogix/CompactLogix
