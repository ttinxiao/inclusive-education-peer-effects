clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"
use "七年级非残疾学生数据_完整变量.dta", clear

// 补全必要变量
gen low_eco = (family_eco <= 2)  // 1=低收入家庭，0=中高收入家庭
label var low_eco "低收入家庭（1=是，0=否）"

// 定义核心变量组
local dependent_vars "interaction_freq relationship_quality parental_investment"
local core_var "has_disabled"
local controls "gender age minority only_child mother_edu father_edu family_eco rural class_size"

// 回归：低收入家庭
estimates clear
local model_num = 1
foreach dep of local dependent_vars {
    areg `dep' `core_var' `controls' if low_eco==1, absorb(schids) robust cluster(schids)
    estimates store hetero_low_`model_num'
    // 输出关键结果
    display "=== 低收入家庭-模型`model_num`（`dep`）==="
    display "`core_var`系数：" %5.3f _b[`core_var'] ", p值：" %5.3f 2*normprob(-abs(_b[`core_var']/_se[`core_var']))
    local model_num = `model_num' + 1
}

//回归：中高收入家庭
local model_num = 1
foreach dep of local dependent_vars {
    areg `dep' `core_var' `controls' if low_eco==0, absorb(schids) robust cluster(schids)
    estimates store hetero_high_`model_num'
    display "=== 中高收入家庭-模型`model_num`（`dep`）==="
    display "`core_var`系数：" %5.3f _b[`core_var'] ", p值：" %5.3f 2*normprob(-abs(_b[`core_var']/_se[`core_var']))
    local model_num = `model_num' + 1
}

// 输出结果表
esttab hetero_low_1 hetero_low_2 hetero_low_3 hetero_high_1 hetero_high_2 hetero_high_3 using "异质性分析_家庭经济水平.rtf", replace ///
    title("表6-1 异质性分析：家庭经济水平差异") ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("样本量" "调整后R²")) ///
    varlabels(`core_var' "班级是否有残疾学生（1=有，0=无）" _cons "常数项") ///
    mlabels("低收入-互动频率" "低收入-关系质量" "低收入-投入感知" "中高收入-互动频率" "中高收入-关系质量" "中高收入-投入感知")