*=========================================================================
* 探索性关联分析：潜在中介变量的条件关联
* X(接触残疾) → M1(学生整体适应) → M2(亲子沟通) → Y(亲子关系)
* 注意：横截面数据，不进行因果中介推断
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

bysort schids clsids: egen disabled_count = total(disabled_student)
bysort schids clsids: egen class_size = count(ids)
gen has_disabled = (disabled_count >= 1)

keep if disabled_student == 0

*---------------------
* 2. 因变量 Y（标准化）
*---------------------
local interaction_vars "b2801 b2802 b2803 b2804 b2805 b2806"
egen interaction_freq_raw = rowmean(`interaction_vars')
egen interaction_freq_std = std(interaction_freq_raw)
label var interaction_freq_std "亲子互动频率(标准化)"

local quality_vars "b2501 b2502"
egen quality_raw = rowmean(`quality_vars')
egen relationship_quality_std = std(quality_raw)
label var relationship_quality_std "亲子关系质量(标准化)"

gen investment_raw = b29
egen parental_investment_std = std(investment_raw)
label var parental_investment_std "父母投入感知(标准化)"

*---------------------
* 3. 控制变量
*---------------------
gen gender      = stsex
label var gender "性别(1=男)"
gen age         = 2013 - a02a if !missing(a02a)
label var age "年龄"
gen minority    = (a03 != 1) if !missing(a03)
label var minority "少数民族(1=是)"
gen only_child  = (stonly==1) if !missing(stonly)
label var only_child "独生子女"
gen rural       = (sthktype==1) if !missing(sthktype)
label var rural "农业户口"
gen father_edu  = stfedu
label var father_edu "父亲教育"
gen mother_edu  = stmedu
label var mother_edu "母亲教育"
gen ses         = steco_5c
label var ses "家庭SES"

local controls "gender age minority only_child rural father_edu mother_edu ses class_size"


*---------------------
* 4. 心理/学校适应变量
*---------------------
* A18 抑郁：1-5量表，反向计分为6-原始分
egen depression_index = rowmean(a1801 a1802 a1803 a1804 a1805)
gen depression_rev = 6 - depression_index

* C11 学习轻松度：1-4量表，正向，不反向
egen study_ease_raw = rowmean(c1101 c1102 c1103)

* A12 自我效能感：1-4量表，正向，不反向
egen self_efficacy = rowmean(a1201 a1202 a1203 a1204 a1205 a1206 a1207)

* C17 学校归属感：1-4量表，正向，不反向
egen school_belonging = rowmean(c1706 c1707 c1708 c1709 c1710)

* C17 学校疏离感：1-4量表，反向计分为5-原始分
egen school_alienation = rowmean(c1711 c1712)
gen school_alienation_rev = 5 - school_alienation

* 标准化各维度
egen z_depression_rev = std(depression_rev)
egen z_study_ease = std(study_ease_raw)
egen z_self_efficacy = std(self_efficacy)
egen z_school_belonging = std(school_belonging)
egen z_school_alienation_rev = std(school_alienation_rev)

* 合成综合适应指数（等权平均）
egen adapt_index = rowmean(z_depression_rev z_study_ease z_self_efficacy z_school_belonging z_school_alienation_rev)
egen adapt_index_std = std(adapt_index)
label var adapt_index_std "综合适应指数（标准化）"

*---------------------
* 5. M2 亲子沟通
*---------------------
* 计算原始均值
egen parent_comm_raw = rowmean(ba1401 ba1402 ba1403 ba1404 ba1405)
* 标准化
egen parent_comm_std = std(parent_comm_raw)
label var parent_comm_std "亲子沟通(标准化)"
*---------------------
* 6. 剔除缺失值（使用标准化因变量和原始均值变量）
*---------------------
drop if missing(interaction_freq_std, relationship_quality_std, parental_investment_std, ///
    adapt_index_std, parent_comm_std, gender, age, minority, only_child, rural, ///
    father_edu, mother_edu, ses, class_size, has_disabled)

*=========================================================================
* 7. 条件关联回归（作探索性关联分析）
*=========================================================================
estimates clear
local y_counter = 1

foreach y_var in interaction_freq_std relationship_quality_std parental_investment_std {
    * Step 1: X -> M1
    reghdfe adapt_index_std has_disabled `controls', absorb(schids) vce(cluster schids)
    estimates store S1_`y_counter'_M1

    * Step 2: M1 -> M2 (控制X)
    reghdfe parent_comm_std has_disabled adapt_index_std `controls', absorb(schids) vce(cluster schids)
    estimates store S2_`y_counter'_M2

    * Step 3: M1, M2 -> Y (控制X)
    reghdfe `y_var' has_disabled adapt_index_std parent_comm_std `controls', absorb(schids) vce(cluster schids)
    estimates store S3_`y_counter'_Y

    local y_counter = `y_counter' + 1
}

*---------------------
* 8. 输出表格
*---------------------
esttab S1_1_M1 S2_1_M2 S3_1_Y using "探索性关联_互动频率.rtf", replace ///
    b(3) se(3) starlevels(* 0.10 ** 0.05 *** 0.01)

esttab S1_2_M1 S2_2_M2 S3_2_Y using "探索性关联_关系质量.rtf", replace ///
    b(3) se(3) starlevels(* 0.10 ** 0.05 *** 0.01)

esttab S1_3_M1 S2_3_M2 S3_3_Y using "探索性关联_父母投入.rtf", replace ///
    b(3) se(3) starlevels(* 0.10 ** 0.05 *** 0.01)

di "探索性关联分析运行成功！"
