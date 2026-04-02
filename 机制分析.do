*=========================================================================
* 机制分析： 链式路径检验
* X(接触残疾) → M1(学生整体适应) → M2(亲子沟通) → Y(亲子关系)
*=========================================================================

clear all
set more off
cd "D:\导师\残疾伙伴与父母关系\Newceps"

use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta", keep(match) nogen
merge m:1 clsids using "CEPS基线调查班级数据.dta", keep(match) nogen

keep if grade9 == 0

*---------------------
* 1. 基础变量
*---------------------
gen disabled_student = (bd1501==1 | bd1502==1 | bd1503==1 | bd1504==1 | bd1505==1 | bd1506==1 | bd1507==1)
replace disabled_student = 0 if missing(disabled_student)

bysort schids clsids: egen class_disabled_count = total(disabled_student)
bysort schids clsids: egen class_size = count(ids)
gen has_disabled = (class_disabled_count >= 1)

keep if disabled_student == 0

*---------------------
* 2. 因变量 Y
*---------------------
egen interaction_freq = rowmean(b2801 b2802 b2803 b2804 b2805 b2806)
egen relationship_quality = rowmean(b2501 b2502)
gen parental_investment = b29

*---------------------
* 3. 控制变量
*---------------------
gen gender = stsex
gen age = 2013 - a02a
gen minority = (a03 != 1)
gen only_child = (stonly == 1)
gen mother_edu = stmedu
gen father_edu = stfedu
gen family_eco = steco_5c
gen rural = (sthktype == 1)

local controls "gender age minority only_child mother_edu father_edu family_eco rural class_size"

*---------------------
* 4. 先生成所有心理/学校变量
*---------------------
egen depression_index = rowmean(a1801 a1802 a1803 a1804 a1805)
egen study_stress_raw = rowmean(c1101 c1102 c1103)
egen self_efficacy = rowmean(a1201 a1202 a1203 a1204 a1205 a1206 a1207)

egen school_belonging = rowmean(c1706 c1707 c1708 c1709 c1710)
egen school_alienation = rowmean(c1711 c1712)

*---------------------
* 5. 反向计分 + 标准化
*---------------------
gen depression_rev = 6 - depression_index
gen study_stress_rev = 6 - study_stress_raw
gen school_alienation_rev = 6 - school_alienation

egen z_depression_rev = std(depression_rev)
egen z_study_stress_rev = std(study_stress_rev)
egen z_self_efficacy = std(self_efficacy)
egen z_school_belonging = std(school_belonging)
egen z_school_alienation_rev = std(school_alienation_rev)

egen adapt_index = rowmean(z_depression_rev z_study_stress_rev z_self_efficacy z_school_belonging z_school_alienation_rev)

*---------------------
* 6. M2 亲子沟通
*---------------------
egen parent_comm = rowmean(ba1401 ba1402 ba1403 ba1404 ba1405)

*---------------------
*---------------------
* 7. 剔除缺失
*---------------------
drop if missing(interaction_freq, relationship_quality, parental_investment, ///
adapt_index, parent_comm, gender, age, minority, only_child, mother_edu, father_edu, family_eco, rural, class_size, has_disabled)

*=========================================================================
* 【链式中介三步回归 】
*=========================================================================

estimates clear
local y_counter = 1

foreach y_var in interaction_freq relationship_quality parental_investment {
    areg adapt_index has_disabled `controls', absorb(schids) robust cluster(schids)
    estimates store S1_`y_counter'_M1
    
    areg parent_comm has_disabled adapt_index `controls', absorb(schids) robust cluster(schids)
    estimates store S2_`y_counter'_M2
    
    areg `y_var' has_disabled adapt_index parent_comm `controls', absorb(schids) robust cluster(schids)
    estimates store S3_`y_counter'_Y
    
    local y_counter = `y_counter' + 1
}

*---------------------
* 输出三张完美表格
*---------------------
esttab S1_1_M1 S2_1_M2 S3_1_Y using "机制分析_互动频率.rtf", replace b(3) se(3) star(* 0.1 ** 0.05 *** 0.01)
esttab S1_2_M1 S2_2_M2 S3_2_Y using "机制分析_关系质量.rtf", replace b(3) se(3) star(* 0.1 ** 0.05 *** 0.01)
esttab S1_3_M1 S2_3_M2 S3_3_Y using "机制分析_父母投入.rtf", replace b(3) se(3) star(* 0.1 ** 0.05 *** 0.01)

di "✅ 你的机制分析代码 —— 完美运行！"