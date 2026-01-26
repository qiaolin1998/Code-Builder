# 产量计算功能块 (Product_Count_SCL - FB300)

## 功能描述

FB300 (Product_Count_SCL) 是一个用于计算班、日、月、年产量的功能块，主要应用于工业自动化系统中的皮带秤产量统计。该功能块可以根据当前时间自动计算不同时间周期的产量，并提供了初始化功能确保数据准确性。

**版本1.1新增功能：**
- 白班每三小时产量计算（9:00-12:00, 12:00-15:00, 15:00-18:00, 18:00-21:00）
- 夜班每三小时产量计算（21:00-24:00, 0:00-3:00, 3:00-6:00, 6:00-9:00）

## 功能特点

1. **多周期产量计算**：
   - 白班产量（9:00-21:00）
   - 夜班产量（21:00-次日9:00）
   - 日产量（9:00-次日9:00）
   - 月产量（每月1日9:00开始）
   - 年产量（每年1月1日9:00开始）
   - 白班每三小时产量（四段）
   - 夜班每三小时产量（四段）

2. **时间处理优化**：
   - 使用系统时钟获取当前时间
   - 采用上一次扫描时间进行比较，确保跨时间点的正确处理
   - 支持跨小时、跨日、跨月和跨年的产量计算

3. **初始化功能**：
   - 首次扫描自动初始化
   - 支持外部触发初始化
   - 初始化完成标志输出

4. **数据准确性保障**：
   - 所有开始产量值保存为静态变量
   - 产量计算采用当前总累计量减去开始产量的方式
   - 避免时间判断的精确性问题

## 接口定义

### 输入参数

| 参数名 | 类型 | 描述 |
|--------|------|------|
| Product_Total | REAL | 实时皮带秤总累计量 |
| Initialize | BOOL | 初始化信号（上升沿有效） |

### 输出参数

| 参数名 | 类型 | 描述 |
|--------|------|------|
| Product_White_Class | REAL | 白班产量 |
| Product_Night_Class | REAL | 夜班产量 |
| Product_Day | REAL | 日产量 |
| Product_Month | REAL | 月产量 |
| Product_Year | REAL | 年产量 |
| Product_White_3H_1 | REAL | 白班第一段产量 (9:00-12:00) |
| Product_White_3H_2 | REAL | 白班第二段产量 (12:00-15:00) |
| Product_White_3H_3 | REAL | 白班第三段产量 (15:00-18:00) |
| Product_White_3H_4 | REAL | 白班第四段产量 (18:00-21:00) |
| Product_Night_3H_1 | REAL | 夜班第一段产量 (21:00-24:00) |
| Product_Night_3H_2 | REAL | 夜班第二段产量 (0:00-3:00) |
| Product_Night_3H_3 | REAL | 夜班第三段产量 (3:00-6:00) |
| Product_Night_3H_4 | REAL | 夜班第四段产量 (6:00-9:00) |
| Init_Done | BOOL | 初始化完成标志 |

## 使用方法

1. **实例化功能块**：
   ```scl
   fbProductCount:Product_Count_SCL;
   ```

2. **调用功能块**：
   ```scl
   fbProductCount(
       Product_Total := Actual_Total_Production,
       Initialize := Init_Signal,
       Product_White_Class => White_Class_Production,
       Product_Night_Class => Night_Class_Production,
       Product_Day => Day_Production,
       Product_Month => Month_Production,
       Product_Year => Year_Production,
       // 白班每三小时产量
       Product_White_3H_1 => White_3H_1_Production,
       Product_White_3H_2 => White_3H_2_Production,
       Product_White_3H_3 => White_3H_3_Production,
       Product_White_3H_4 => White_3H_4_Production,
       // 夜班每三小时产量
       Product_Night_3H_1 => Night_3H_1_Production,
       Product_Night_3H_2 => Night_3H_2_Production,
       Product_Night_3H_3 => Night_3H_3_Production,
       Product_Night_3H_4 => Night_3H_4_Production,
       Init_Done => Initialization_Done
   );
   ```

3. **初始化操作**：
   - 功能块首次扫描会自动初始化
   - 也可以通过外部触发`Initialize`信号进行手动初始化
   - 初始化完成后，`Init_Done`标志会置位

## 实现原理

1. **时间获取**：使用`READ_CLK`指令获取当前系统时间，并转换为便于处理的整数格式

2. **时间比较**：
   - 保存当前时间作为下一次扫描的上一次时间
   - 使用上一次时间与当前时间比较，判断是否进入新的时间周期

3. **产量计算**：
   - 当进入新的时间周期时，记录当前总累计量作为开始产量
   - 实时产量 = 当前总累计量 - 开始产量

4. **初始化机制**：
   - 首次扫描：将所有开始产量初始化为当前总累计量
   - 手动初始化：重置所有开始产量和当前产量

## 测试方法

1. **测试程序**：`Test_FB300.scl` 提供了完整的测试程序

2. **测试流程**：
   - 模拟皮带秤总累计量的增加
   - 验证不同时间周期的产量计算
   - 测试初始化功能
   - 监控新增的每三小时产量输出

3. **测试步骤**：
   - 编译并下载程序到PLC
   - 监控`Test_Product_Total`变量的变化
   - 观察各产量输出变量的变化
   - 触发初始化信号，验证初始化功能

## 注意事项

1. **时间同步**：确保PLC系统时间准确并与实际时间同步

2. **总累计量准确性**：`Product_Total`输入必须是准确的皮带秤总累计量

3. **初始化时机**：建议在系统启动或生产周期开始时进行初始化

4. **扫描周期**：功能块的扫描周期应足够短，以确保时间判断的准确性

## 版本信息

- **版本**：1.1
- **作者**：ZQF
- **创建日期**：2023
- **更新日志**：
  - V1.0：初始版本，实现班、日、月、年产量计算
  - V1.1：新增白班与夜班每三小时产量计算功能

## 文件列表

- `FB300_Product_Count_SCL.scl`：功能块主程序
- `Test_FB300.scl`：测试程序
- `README.md`：功能说明文档

## 应用场景

该功能块适用于需要统计不同时间周期产量的工业自动化系统，如：
- 皮带秤产量统计
- 生产线产量管理
- 生产报表生成
- 生产数据分析

## 扩展建议

1. **添加数据存储功能**：将产量数据存储到PLC的非易失性存储器中，避免断电丢失

2. **增加报表生成功能**：根据产量数据自动生成班报、日报、月报和年报

3. **添加异常处理**：检测产量异常波动并输出报警信号

4. **支持多生产线**：扩展为支持多条生产线的产量统计