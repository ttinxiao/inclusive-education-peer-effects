*==================================================
* Table1 + Table2 (含minority+样本量N)
* 因变量：原始均值用于描述统计，标准化用于主回归
*==================================================
clear all
set more off
cd "D:\导师\残疾伙伴与父母关系\Newceps"

use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta"
keep if _merge==3
drop _merge

merge m:1 clsids using "CEPS基线调查班级数据.dta"
keep if _merge==3
drop _merge

keep if grade9 == 0

* 残疾变量
gen disabled_student = (bd1501==1|bd1502==1|bd1503==1|bd1504==1|bd1505==1|bd1506==1|bd1507==1)
replace disabled_student = 0 if missing(disabled_student)

bysort clsids: egen disabled_count = total(disabled_student)
gen has_disabled = (disabled_count >= 1)
label var has_disabled "班级中是否有残疾同伴 (1=是)"

* 控制变量
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
bysort clsids: egen class_size = count(ids)
label var class_size "班级规模"

*------------------------------------
* 因变量：原始均值（用于描述统计）
*------------------------------------
local interaction_vars "b2801 b2802 b2803 b2804 b2805 b2806"
egen interaction_freq_raw = rowmean(`interaction_vars')
label var interaction_freq_raw "Parent-child interaction frequency (raw mean, 1-6)"

local quality_vars "b2501 b2502"
egen quality_raw = rowmean(`quality_vars')
label var quality_raw "Parent-child relationship quality (raw mean, 1-3)"

gen investment_raw = b29
label var investment_raw "Perceived parental support (raw item, 1-5)"

*------------------------------------
* 因变量：标准化 z 分数（用于主回归，不截断）
*------------------------------------
egen interaction_freq_std = std(interaction_freq_raw)
label var interaction_freq_std "Parent-child interaction frequency (standardized)"

egen relationship_quality_std = std(quality_raw)
label var relationship_quality_std "Parent-child relationship quality (standardized)"

egen parental_investment_std = std(investment_raw)
label var parental_investment_std "Perceived parental support (standardized)"

* 残疾比例
gen disabled_ratio = disabled_count / class_size
label var disabled_ratio "班级残疾比例"

*------------------------------------
* 样本筛选：保留非残疾学生并删除关键变量缺失
*------------------------------------
keep if disabled_student == 0
drop if missing(interaction_freq_raw, quality_raw, investment_raw, ///
    gender, age, minority, only_child, rural, father_edu, mother_edu, ses, class_size, has_disabled)

*==================== 样本信息输出 ====================
quietly count
local N_students = r(N)

quietly levelsof clsids, local(classlist)
local N_classes : word count `classlist'

quietly levelsof schids, local(schoollist)
local N_schools : word count `schoollist'

di as text _n "==================== 样本信息 ===================="
di as text "学生人数 = " as result `N_students'
di as text "班级数   = " as result `N_classes'
di as text "学校数   = " as result `N_schools'
di as text "=================================================="

*==================================================
* Table 1 整体描述统计：使用原始均值变量
*==================================================
local desc_vars ///
    interaction_freq_raw quality_raw investment_raw ///
    has_disabled disabled_ratio ///
    gender age minority only_child rural ///
    father_edu mother_edu ses class_size

eststo clear
estpost summarize `desc_vars'

esttab using "Table1_最终版.rtf", replace ///
    cells("count(fmt(%9.0f)) mean(fmt(3)) sd(fmt(3)) min(fmt(1)) max(fmt(1))") ///
    collabels("N" "Mean" "SD" "Min" "Max") ///
    title("Table 1 Descriptive Statistics") ///
    nonumber noobs ///
    addnotes("Notes: Non-disabled 7th graders only. Raw mean scores reported for outcome variables.")

*==================================================
* Table 2 分组描述统计：使用原始均值变量
*==================================================
local group_vars ///
    interaction_freq_raw quality_raw investment_raw ///
	has_disabled disabled_ratio ///
    gender age minority only_child rural ///
    father_edu mother_edu ses class_size 

eststo clear
quietly count if has_disabled==0
local n0 = r(N)
estpost summarize `group_vars' if has_disabled==0
eststo group0
estadd scalar N_group = `n0'

quietly count if has_disabled==1
local n1 = r(N)
estpost summarize `group_vars' if has_disabled==1
eststo group1
estadd scalar N_group = `n1'

esttab group0 group1 using "Table2_分组描述统计_最终版.rtf", replace ///
    cell(mean(fmt(3)) sd(fmt(3))) ///
    mtitles("无残疾同伴" "有残疾同伴") ///
    nonumber ///
    title("Table 2 Group Descriptive Statistics") ///
    stats(N_group, fmt(0) labels("Obs.")) ///
    addnotes("Notes: Non-disabled 7th graders only. Raw mean scores reported for outcome variables. SD in parentheses.")