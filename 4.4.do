// 加载基线回归使用的完整数据
clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"
use "七年级非残疾学生数据_完整变量.dta", clear

// 定义核心变量组
local dependent_vars "interaction_freq relationship_quality parental_investment"  // 3个亲子关系因变量
local independent_var "has_disabled"  // 核心解释变量：班级是否有残疾学生
local control_vars "gender age minority only_child mother_edu father_edu family_eco rural class_size"  // 控制变量组


// 步骤1：确保班级标识变量（clsids）存在
describe clsids  // 验证变量存在

// 步骤2：用班级固定效应重新回归
estimates clear
local model_num = 1
foreach dep_var of local dependent_vars {
    // 回归命令：absorb(clsids) 控制班级固定效应，其他设定与基线一致
    areg `dep_var' `independent_var' `control_vars', absorb(clsids) robust cluster(schids)
    estimates store robust4_model_`model_num'  // 存储模型设定检验结果（标记为robust4）
    
    // 输出核心结果
    display "=== 稳健性检验4-模型`model_num`：因变量=`dep_var` ==="
    display "班级有残疾学生系数：" %5.3f _b[`independent_var'] ", p值：" %5.3f 2*normprob(-abs(_b[`independent_var']/_se[`independent_var']))
    local model_num = `model_num' + 1
}

// 步骤3：输出模型设定检验结果表
esttab robust4_model_1 robust4_model_2 robust4_model_3 using "稳健性检验4_替换固定效应.rtf", replace ///
    title("表X4 稳健性检验：替换固定效应（从学校到班级）") ///
    b(3) se(3)  ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("样本量" "调整后R²")) ///
    varlabels(`independent_var' "班级有残疾学生" _cons "常数项") ///
    mlabels("亲子互动频率" "亲子关系质量" "父母投入感知") ///
    addnotes("注：模型控制班级固定效应（absorb(clsids)），而非基线的学校固定效应，检验结果对固定效应层级的敏感性")