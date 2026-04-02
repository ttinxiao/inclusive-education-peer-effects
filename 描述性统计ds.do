*==================================================
* 最终完美无错版：Table1 + Table2 (含minority+样本量N)
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
gen treat = (disabled_count >= 1)
label var treat "班级是否有残疾同伴"

* 控制变量
gen gender      = stsex
label var gender "性别(1=男)"
gen age         = 2013 - a02a
label var age "年龄"
gen minority    = (a03 != 1) if !missing(a03)
label var minority "少数民族(1=是)"
gen only_child  = (stonly==1)
replace only_child = 0 if missing(only_child)
label var only_child "独生子女"
gen rural       = (sthktype == 1)
label var rural "农业户口"
gen father_edu  = stfedu
label var father_edu "父亲教育"
gen mother_edu  = stmedu
label var mother_edu "母亲教育"
gen ses         = steco_5c
label var ses "家庭SES"
bysort clsids: egen class_size = count(ids)
label var class_size "班级规模"

* 因变量
local interaction_vars "b2801 b2802 b2803 b2804 b2805 b2806"
egen interaction_freq_raw = rowmean(`interaction_vars')
egen interaction_freq = std(interaction_freq_raw)
replace interaction_freq = (interaction_freq + 3) * 20
replace interaction_freq = 0 if interaction_freq < 0
replace interaction_freq = 100 if interaction_freq > 100
label var interaction_freq "亲子互动频率"

local quality_vars "b2501 b2502"
egen quality_raw = rowmean(`quality_vars')
egen relationship_quality = std(quality_raw)
replace relationship_quality = (relationship_quality + 3) * 20
replace relationship_quality = 0 if relationship_quality < 0
replace relationship_quality = 100 if relationship_quality > 100
label var relationship_quality "亲子关系质量"

gen investment_raw = b29
egen parental_investment = std(investment_raw)
replace parental_investment = (parental_investment + 3) * 20
replace parental_investment = 0 if parental_investment < 0
replace parental_investment = 100 if parental_investment > 100
label var parental_investment "父母投入感知"

* 残疾比例
gen disabled_ratio = disabled_count / class_size
label var disabled_ratio "班级残疾比例"

* 样本筛选
keep if disabled_student == 0
drop if missing(parental_investment, interaction_freq, relationship_quality, ///
    gender, age, minority, only_child, rural, father_edu, mother_edu, ses, class_size, treat)

*==================================================
* Table 1 整体描述统计
*==================================================
local desc_vars ///
parental_investment interaction_freq relationship_quality ///
treat disabled_ratio ///
gender age minority only_child rural ///
father_edu mother_edu ses class_size

eststo clear
estpost summarize `desc_vars'

esttab using "Table1_最终版.rtf", replace ///
    cells("count(fmt(%9.0f)) mean(fmt(3)) sd(fmt(3)) min(fmt(1)) max(fmt(1))") ///
    collabels("N" "Mean" "SD" "Min" "Max") ///
    title("Table 1 Descriptive Statistics") ///
    nonumber noobs ///
    addnotes("Notes: Non-disabled 7th graders only.")

*==================================================
* Table 2 分组描述统计
*==================================================
local group_vars ///
parental_investment interaction_freq relationship_quality ///
gender age minority only_child rural ///
father_edu mother_edu ses class_size disabled_ratio

eststo clear
estpost summarize `group_vars' if treat==0
eststo group0

estpost summarize `group_vars' if treat==1
eststo group1


esttab group0 group1 using "Table2_分组描述统计_最终版.rtf", replace ///
    cell(mean(fmt(2)) sd(fmt(2))) ///
    mtitles("无残疾同伴" "有残疾同伴") ///
    nonumber ///
    title("Table 2 Group Descriptive Statistics") ///
    stats(N, fmt(0)) ///
    addnotes("Notes: Non-disabled 7th graders only. SD in parentheses.")

di "✅ 全部运行成功！两个表格已生成！"