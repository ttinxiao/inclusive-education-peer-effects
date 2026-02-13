clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"
use "七年级非残疾学生数据_完整变量.dta", clear

// 定义核心变量组
local dependent_vars "interaction_freq relationship_quality parental_investment"
local core_var "has_disabled"
local controls "gender age minority only_child mother_edu father_edu family_eco rural class_size"

// 性别变量标签（gender：1=男性，0=女性）
label var gender "性别（1=男性，0=女性）"

// 回归：女性
estimates clear
local model_num = 1
foreach dep of local dependent_vars {
    areg `dep' `core_var' `controls' if gender==0, absorb(schids) robust cluster(schids)
    estimates store hetero_female_`model_num'
    display "=== 女性-模型`model_num`（`dep`）==="
    display "`core_var`系数：" %5.3f _b[`core_var'] ", p值：" %5.3f 2*normprob(-abs(_b[`core_var']/_se[`core_var']))
    local model_num = `model_num' + 1
}

// 回归：男
local model_num = 1
foreach dep of local dependent_vars {
    areg `dep' `core_var' `controls' if gender==1, absorb(schids) robust cluster(schids)
    estimates store hetero_male_`model_num'
    display "=== 男性-模型`model_num`（`dep`）==="
    display "`core_var`系数：" %5.3f _b[`core_var'] ", p值：" %5.3f 2*normprob(-abs(_b[`core_var']/_se[`core_var']))
    local model_num = `model_num' + 1
}

// 输出结果表
esttab hetero_female_1 hetero_female_2 hetero_female_3 hetero_male_1 hetero_male_2 hetero_male_3 using "异质性分析_性别.rtf", replace ///
    title("表6-3 异质性分析：性别差异") ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("样本量" "调整后R²")) ///
    varlabels(`core_var' "班级是否有残疾学生（1=有，0=无）" _cons "常数项") ///
    mlabels("女性-互动频率" "女性-关系质量" "女性-投入感知" "男性-互动频率" "男性-关系质量" "男性-投入感知")