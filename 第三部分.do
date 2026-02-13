clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"
use "七年级非残疾学生数据_完整变量.dta", clear

// 定义核心变量组
local dependent_vars "interaction_freq relationship_quality parental_investment"
local independent_var "has_disabled"
local control_vars "gender age minority only_child mother_edu father_edu family_eco rural class_size"

// 基线回归：学校固定效应模型
estimates clear
local model_num = 1
foreach dep_var of local dependent_vars {
    areg `dep_var' `independent_var' `control_vars', absorb(schids) robust cluster(schids)
    estimates store model_`model_num'
    display "=== 模型`model_num'：因变量=`dep_var' ==="
    local model_num = `model_num' + 1
}

// 使用esttab输出RTF格式
esttab model_1 model_2 model_3 using "基线回归结果表.rtf", ///
    title("表4-1 班级是否有残疾学生对亲子关系的平均效应（学校固定效应模型）") ///
    b(3) se(3) ///  // 使用简写格式，确保系数和标准误同行显示
    star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("样本量" "调整后R²")) ///
    varlabels(has_disabled "班级有残疾学生" _cons "常数项") ///
    replace
    
