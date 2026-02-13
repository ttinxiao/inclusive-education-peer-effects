// 加载基线回归使用的完整数据
clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"
use "七年级非残疾学生数据_完整变量.dta", clear

// 定义核心变量组
local dependent_vars "interaction_freq relationship_quality parental_investment"  // 3个亲子关系因变量
local independent_var "has_disabled"  // 核心解释变量：班级是否有残疾学生
local control_vars "gender age minority only_child mother_edu father_edu family_eco rural class_size"  // 控制变量组


// 计算班级残疾学生比例
gen disabled_ratio = class_disabled_count / class_size 
replace disabled_ratio = 0 if missing(disabled_ratio)  // 处理可能的缺失值（如班级人数为0的极端情况）
label var disabled_ratio "班级残疾学生比例"
sum disabled_ratio, detail  // 验证比例分布

// 步骤2：重新进行学校固定效应回归（替换解释变量）
estimates clear  // 清空之前的回归结果
local model_num = 1  // 模型编号，对应3个因变量
foreach dep_var of local dependent_vars {
    // 回归命令：absorb(schids)控制学校固定效应，标准误按学校聚类
    areg `dep_var' disabled_ratio `control_vars', absorb(schids) robust cluster(schids)
    estimates store robust1_model_`model_num'  // 存储稳健性检验结果（robust1）
    // 输出核心结果
    display "=== 稳健性检验1-模型`model_num`：因变量=`dep_var` ==="
    display "班级残疾学生比例系数：" %5.3f _b[disabled_ratio] ", p值：" %5.3f 2*normprob(-abs(_b[disabled_ratio]/_se[disabled_ratio]))
    local model_num = `model_num' + 1
}

// 步骤3：输出替换解释变量后的结果表
// 定义模型列标题的局部宏
local mlabel1 "亲子互动频率"
local mlabel2 "亲子关系质量"
local mlabel3 "父母投入感知"
esttab robust1_model_1 robust1_model_2 robust1_model_3 using "稳健性检验1_替换解释变量.rtf", replace ///
    title("表X1 稳健性检验：替换核心解释变量（班级残疾学生比例）") ///
    b(3) se(3) ///  系数、标准误均保留3位小数
    star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("样本量" "调整后R²")) ///
    varlabels(disabled_ratio "班级残疾学生比例" _cons "常数项") ///
    mlabels("亲子互动频率" "亲子关系质量" "父母投入感知") ///
    addnotes("注：1. 标准误按学校层面聚类；2. 控制变量包括：性别、年龄、少数民族、独生子女、父母教育年限、家庭经济状况、农村户口、班级规模；3. *p<0.1, **p<0.05, ***p<0.01")