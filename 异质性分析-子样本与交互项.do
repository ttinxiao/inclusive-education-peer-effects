*=========================================================================
* 异质性分析：子样本法 + 交互项检验
* 分组：家庭经济水平(SES)、是否独生子女、学生性别
*=========================================================================
clear all
set more off
cd "D:\导师\残疾伙伴与父母关系\Newceps"

*---------------------
* 1. 数据准备
*---------------------
use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta", keep(match) nogenerate
merge m:1 clsids using "CEPS基线调查班级数据.dta", keep(match) nogenerate
keep if grade9 == 0

*---------------------
* 2. 核心变量生成
*---------------------
gen disabled_student = (bd1501==1 | bd1502==1 | bd1503==1 | bd1504==1 | bd1505==1 | bd1506==1 | bd1507==1)
replace disabled_student = 0 if missing(disabled_student)

bysort schids clsids: egen disabled_count = total(disabled_student)
bysort schids clsids: egen class_size = count(ids)
gen has_disabled = (disabled_count >= 1)
label var has_disabled "班级是否有残疾同伴(1=是)"

keep if disabled_student == 0

*---------------------
* 3. 因变量：原始均值 + 标准化
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
* 4. 控制变量
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

*---------------------
* 5. 异质性分组变量
*---------------------
gen low_SES = (ses <= 2) if !missing(ses)
label var low_SES "低家庭SES(1=是)"

gen is_only_child = (stonly == 1) if !missing(stonly)
label var is_only_child "独生子女(1=是)"

gen is_female = (stsex == 0) if !missing(stsex)
label var is_female "女性(1=是)"

*---------------------
* 6. 缺失值统一删除
*---------------------
drop if missing(interaction_freq_std, relationship_quality_std, parental_investment_std, ///
    has_disabled, gender, age, minority, only_child, rural, father_edu, mother_edu, ses, class_size, ///
    low_SES, is_only_child, is_female)

*---------------------
* 7. 控制变量宏
*---------------------
* 包含性别（用于SES和独生子女异质性）
local controls_all "gender age minority only_child rural father_edu mother_edu ses class_size"
* 不包含性别（用于性别异质性）
local controls_nogender "age minority only_child rural father_edu mother_edu ses class_size"

local dependent_vars "interaction_freq_std relationship_quality_std parental_investment_std"
local core_var "has_disabled"

*---------------------
* 8. SES异质性分析
*---------------------
* 生成交互项
gen has_disabled_X_lowSES = has_disabled * low_SES

estimates clear
local model_num = 1
foreach dep of local dependent_vars {
    * 低SES组
    reghdfe `dep' `core_var' `controls_all' if low_SES==1, absorb(schids) vce(cluster schids)
    estimates store low_`model_num'
    * 中高SES组
    reghdfe `dep' `core_var' `controls_all' if low_SES==0, absorb(schids) vce(cluster schids)
    estimates store high_`model_num'
    * 交互项模型（全样本）
    reghdfe `dep' `core_var' low_SES has_disabled_X_lowSES `controls_all', absorb(schids) vce(cluster schids)
    estimates store inter_`model_num'
    local model_num = `model_num' + 1
}

* 输出：子样本 + 交互项（仅保留核心系数）
esttab low_1 high_1 inter_1 low_2 high_2 inter_2 low_3 high_3 inter_3 ///
    using "异质性_SES.rtf", replace ///
    title("Heterogeneity by Family SES") ///
    b(3) se(3) starlevels(* 0.10 ** 0.05 *** 0.01) ///
    keep(has_disabled low_SES has_disabled_X_lowSES) ///
    stats(N, fmt(0) labels("N")) ///
    mlabels("Low SES" "Mid/High SES" "Interaction" "Low SES" "Mid/High SES" "Interaction" "Low SES" "Mid/High SES" "Interaction") ///
    nonumbers ///
    addnotes("Notes: All outcomes are standardized. School fixed effects included. Standard errors clustered at school level. Interaction term tests difference between low-SES and mid/high-SES groups. * p<0.1, ** p<0.05, *** p<0.01")

*---------------------
* 9. 独生子女异质性分析
*---------------------
gen has_disabled_X_onlychild = has_disabled * is_only_child

estimates clear
local model_num = 1
foreach dep of local dependent_vars {
    * 独生子女组
    reghdfe `dep' `core_var' `controls_all' if is_only_child==1, absorb(schids) vce(cluster schids)
    estimates store only_`model_num'
    * 非独生子女组
    reghdfe `dep' `core_var' `controls_all' if is_only_child==0, absorb(schids) vce(cluster schids)
    estimates store nononly_`model_num'
    * 交互项模型
    reghdfe `dep' `core_var' is_only_child has_disabled_X_onlychild `controls_all', absorb(schids) vce(cluster schids)
    estimates store inter_`model_num'
    local model_num = `model_num' + 1
}

esttab nononly_1 only_1 inter_1 nononly_2 only_2 inter_2 nononly_3 only_3 inter_3 ///
    using "异质性_独生子女.rtf", replace ///
    title("Heterogeneity by Only-Child Status") ///
    b(3) se(3) starlevels(* 0.10 ** 0.05 *** 0.01) ///
    keep(has_disabled is_only_child has_disabled_X_onlychild) ///
    stats(N, fmt(0) labels("N")) ///
    mlabels("Non-only" "Only" "Interaction" "Non-only" "Only" "Interaction" "Non-only" "Only" "Interaction") ///
    nonumbers ///
    addnotes("Notes: All outcomes are standardized. School fixed effects included. Standard errors clustered at school level. Interaction term tests difference between only-child and non-only-child groups. * p<0.1, ** p<0.05, *** p<0.01")

*---------------------
* 10. 性别异质性分析
*---------------------
gen has_disabled_X_female = has_disabled * is_female

estimates clear
local model_num = 1
foreach dep of local dependent_vars {
    * 女性组
    reghdfe `dep' `core_var' `controls_nogender' if is_female==1, absorb(schids) vce(cluster schids)
    estimates store female_`model_num'
    * 男性组
    reghdfe `dep' `core_var' `controls_nogender' if is_female==0, absorb(schids) vce(cluster schids)
    estimates store male_`model_num'
    * 交互项模型
    reghdfe `dep' `core_var' is_female has_disabled_X_female `controls_nogender', absorb(schids) vce(cluster schids)
    estimates store inter_`model_num'
    local model_num = `model_num' + 1
}

esttab female_1 male_1 inter_1 female_2 male_2 inter_2 female_3 male_3 inter_3 ///
    using "异质性_性别.rtf", replace ///
    title("Heterogeneity by Student Gender") ///
    b(3) se(3) starlevels(* 0.10 ** 0.05 *** 0.01) ///
    keep(has_disabled is_female has_disabled_X_female) ///
    stats(N, fmt(0) labels("N")) ///
    mlabels("Female" "Male" "Interaction" "Female" "Male" "Interaction" "Female" "Male" "Interaction") ///
    nonumbers ///
    addnotes("Notes: All outcomes are standardized. School fixed effects included. Standard errors clustered at school level. Interaction term tests difference between female and male students. * p<0.1, ** p<0.05, *** p<0.01")

di "异质性分析完成！三张表格已输出。"