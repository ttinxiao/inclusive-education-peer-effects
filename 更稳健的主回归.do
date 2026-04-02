clear all
set more off
cd "D:\导师\残疾伙伴与父母关系\Newceps"

use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta", keep(match) nogen
merge m:1 clsids using "CEPS基线调查班级数据.dta", keep(match) nogen

keep if grade9 == 0

*---------------------
* 1. 残疾学生定义
*---------------------
gen disabled_student = (bd1501==1 | bd1502==1 | bd1503==1 | bd1504==1 | bd1505==1 | bd1506==1 | bd1507==1)
replace disabled_student = 0 if missing(disabled_student)

*---------------------
* 2. 班级级变量
*---------------------
bysort schids clsids: egen disabled_count = total(disabled_student)
bysort schids clsids: egen class_size = count(ids)
gen has_disabled = (disabled_count >= 1)
gen disabled_ratio = disabled_count / class_size

*---------------------
* 3. 分组变量 0 / 1 / 2-3 / 4+
*---------------------
gen disabled_group = .
replace disabled_group = 0 if disabled_count == 0
replace disabled_group = 1 if disabled_count == 1
replace disabled_group = 2 if disabled_count >=2 & disabled_count <=3
replace disabled_group = 3 if disabled_count >=4

label define dis_label 0 "No disabled" 1 "1 Disabled" 2 "2-3 Disabled" 3 "4+ Disabled"
label values disabled_group dis_label

*---------------------
* 4. 仅保留非残疾学生
*---------------------
keep if disabled_student == 0

*---------------------
* 5. 因变量
*---------------------
egen interaction_freq = rowmean(b2801 b2802 b2803 b2804 b2805 b2806)
egen relationship_quality = rowmean(b2501 b2502)
gen parental_investment = b29

*---------------------
* 6. 控制变量
*---------------------
gen gender = stsex
gen age = 2013 - a02a
gen minority = (a03 != 1)
gen only_child = (stonly == 1)
gen rural = (sthktype == 1)
gen father_edu = stfedu
gen mother_edu = stmedu
gen ses = steco_5c

*---------------------
* 7. 剔除缺失值
*---------------------
keep if !missing(parental_investment, interaction_freq, relationship_quality, ///
    gender, age, minority, only_child, rural, father_edu, mother_edu, ses)

*=========================================================================
* ✅ Table 3: 主回归——平均效应
*=========================================================================
eststo clear
eststo: reg interaction_freq has_disabled gender age minority only_child rural father_edu mother_edu ses i.schids, robust
eststo: reg relationship_quality has_disabled gender age minority only_child rural father_edu mother_edu ses i.schids, robust
eststo: reg parental_investment has_disabled gender age minority only_child rural father_edu mother_edu ses i.schids, robust

esttab using "Table3_Baseline_Main.rtf", replace ///
    title("Table 3: Average Effect of Disabled Peers on Parent-Child Relationships") ///
    mtitles("Interaction Frequency" "Relationship Quality" "Parental Investment") ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    coeflabels(has_disabled "Has Disabled Peers") ///
    keep(has_disabled) ///
    ci nonumber compress

*=========================================================================
* ✅ Table 4: 剂量效应
*=========================================================================
eststo clear
eststo: reg interaction_freq i.disabled_group gender age minority only_child rural father_edu mother_edu ses i.schids, robust
eststo: reg relationship_quality i.disabled_group gender age minority only_child rural father_edu mother_edu ses i.schids, robust
eststo: reg parental_investment i.disabled_group gender age minority only_child rural father_edu mother_edu ses i.schids, robust

esttab using "Table4_Dosage_Effect.rtf", replace ///
    title("Table 4: Effects by Number of Disabled Peers") ///
    mtitles("Interaction Frequency" "Relationship Quality" "Parental Investment") ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    coeflabels(1.disabled_group "1 Disabled" 2.disabled_group "2-3 Disabled" 3.disabled_group "4+ Disabled") ///
    keep(*.disabled_group) ///
    ci nonumber compress
	
*=========================================================================
* 效应量和最小可检测效应计算
*=========================================================================
* 获取结果变量的标准差
sum interaction_freq
local sd_interaction = r(sd)
sum relationship_quality
local sd_quality = r(sd)
sum parental_investment
local sd_investment = r(sd)

* 重新运行回归获取系数和标准误（聚类标准误）
reg interaction_freq has_disabled gender age minority only_child rural father_edu mother_edu ses i.schids, robust cluster(schids)
local coef_interaction = _b[has_disabled]
local se_interaction = _se[has_disabled]

reg relationship_quality has_disabled gender age minority only_child rural father_edu mother_edu ses i.schids, robust cluster(schids)
local coef_quality = _b[has_disabled]
local se_quality = _se[has_disabled]

reg parental_investment has_disabled gender age minority only_child rural father_edu mother_edu ses i.schids, robust cluster(schids)
local coef_investment = _b[has_disabled]
local se_investment = _se[has_disabled]

* 计算Cohen's d
local d_interaction = `coef_interaction' / `sd_interaction'
local d_quality = `coef_quality' / `sd_quality'
local d_investment = `coef_investment' / `sd_investment'

* 计算MDE (α=0.05, power=0.80)
local mde_interaction = `se_interaction' * 2.8
local mde_quality = `se_quality' * 2.8
local mde_investment = `se_investment' * 2.8

* 输出结果
di ""
di "=== 效应量 (Cohen's d) ==="
di "Interaction Frequency: " `d_interaction'
di "Relationship Quality: " `d_quality'
di "Parental Investment: " `d_investment'
di ""
di "=== 最小可检测效应 (MDE) ==="
di "Interaction Frequency: " `mde_interaction'
di "Relationship Quality: " `mde_quality'
di "Parental Investment: " `mde_investment'

di ""
di "✅ 所有表格和统计量已生成！"