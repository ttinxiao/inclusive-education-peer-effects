clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"
use "七年级非残疾学生数据_完整变量.dta", clear

// 定义核心变量组
local dependent_vars "interaction_freq relationship_quality parental_investment"
local core_var "has_disabled"  // 核心解释变量：班级是否有残疾学生
local control_vars "gender age minority only_child mother_edu father_edu family_eco rural class_size"

// 生成中介变量
// 1. 心理类中介变量
egen depression_index = rowmean(a1801 a1802 a1803 a1804 a1805) 
label var depression_index "抑郁情绪指数（1-5分，越高抑郁越强）"

egen study_stress_raw = rowmean(c1101 c1102 c1103)
gen study_stress = 6 - study_stress_raw  // 反向计分
drop study_stress_raw
label var study_stress "学业压力（1-5分，越高压力越大）"

egen self_efficacy = rowmean(a1201 a1202 a1203 a1204 a1205 a1206 a1207)
label var self_efficacy "自我效能感（1-4分，越高自信越强）"

// 2. 学校体验类中介变量
egen school_belonging = rowmean(c1706 c1707 c1708 c1709 c1710)
label var school_belonging "学校归属感（1-4分，越高归属感越强）"

egen school_alienation = rowmean(c1711 c1712)
label var school_alienation "学校疏离感（1-4分，越高疏离感越强）"

// 定义中介变量组
local mediator_psych "depression_index study_stress self_efficacy"  // 心理类
local mediator_school "school_belonging school_alienation"         // 学校体验类

// ===================== 心理类中介变量回归 =====================
estimates clear  // 清空结果，仅存储心理类中介的回归结果
local med_num = 1

// 检验心理类中介
foreach med of local mediator_psych {
    areg `med' `core_var' `control_vars', absorb(schids) robust cluster(schids)
    estimates store med_psych_`med_num'  // 命名区分心理类
    display "=== 心理中介`med_num`（`med`）==="
    display "`core_var`系数：" %5.3f _b[`core_var'] ", p值：" %5.3f 2*normprob(-abs(_b[`core_var']/_se[`core_var']))
    local med_num = `med_num' + 1
}

// 导出心理类中介结果表
esttab med_psych_1 med_psych_2 med_psych_3 using "机制分析_心理类中介变量影响.rtf", replace ///
    title("表5-1a 核心变量对心理类中介变量的影响（适配CEPS数据）") ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("样本量" "调整后R²")) ///
    varlabels(`core_var' "班级是否有残疾学生（1=有，0=无）" _cons "常数项") ///
    mlabels("抑郁情绪指数" "学业压力" "自我效能感")  //

// ===================== 学校体验类中介变量回归 =====================
estimates clear  // 清空结果，仅存储学校体验类中介的回归结果
local med_num = 1

// 检验学校体验类中介
foreach med of local mediator_school {
    areg `med' `core_var' `control_vars', absorb(schids) robust cluster(schids)
    estimates store med_school_`med_num'  // 命名区分学校体验类
    display "=== 学校体验中介`med_num`（`med`）==="
    display "`core_var`系数：" %5.3f _b[`core_var'] ", p值：" %5.3f 2*normprob(-abs(_b[`core_var']/_se[`core_var']))
    local med_num = `med_num' + 1
}

// 导出学校体验类中介结果表
esttab med_school_1 med_school_2 using "机制分析_学校体验类中介变量影响.rtf", replace ///
    title("表5-1b 核心变量对学校体验类中介变量的影响（适配CEPS数据）") ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("样本量" "调整后R²")) ///
    varlabels(`core_var' "班级是否有残疾学生（1=有，0=无）" _cons "常数项") ///
    mlabels("学校归属感" "学校疏离感")  // 仅对应2个学校体验中介变量

