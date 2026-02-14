clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"
use "七年级非残疾学生数据_完整变量.dta", clear

// 定义核心变量组
local dependent_vars "interaction_freq relationship_quality parental_investment"
local core_var "has_disabled"
local controls "gender age minority only_child mother_edu father_edu family_eco rural class_size"

// 生成独生子女分组变量（only_child：1=是，0=否）
label var only_child "是否独生子女（1=是，0=否）"

// 回归：独生子女
estimates clear
local model_num = 1
foreach dep of local dependent_vars {
    areg `dep' `core_var' `controls' if only_child==1, absorb(schids) robust cluster(schids)
    estimates store hetero_only_`model_num'
    display "=== 独生子女-模型`model_num`（`dep`）==="
    display "`core_var`系数：" %5.3f _b[`core_var'] ", p值：" %5.3f 2*normprob(-abs(_b[`core_var']/_se[`core_var']))
    local model_num = `model_num' + 1
}

// 回归：非独生子女
local model_num = 1
foreach dep of local dependent_vars {
    areg `dep' `core_var' `controls' if only_child==0, absorb(schids) robust cluster(schids)
    estimates store hetero_sibling_`model_num'
    display "=== 非独生子女-模型`model_num`（`dep`）==="
    display "`core_var`系数：" %5.3f _b[`core_var'] ", p值：" %5.3f 2*normprob(-abs(_b[`core_var']/_se[`core_var']))
    local model_num = `model_num' + 1
}

//  输出结果表
esttab hetero_only_1 hetero_only_2 hetero_only_3 hetero_sibling_1 hetero_sibling_2 hetero_sibling_3 using "异质性分析_是否独生子女.rtf", replace ///
    title("表6-2 异质性分析：是否独生子女差异") ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("样本量" "调整后R²")) ///
    varlabels(`core_var' "班级是否有残疾学生（1=有，0=无）" _cons "常数项") ///
    mlabels("独生子女-互动频率" "独生子女-关系质量" "独生子女-投入感知" "非独生子女-互动频率" "非独生子女-关系质量" "非独生子女-投入感知")