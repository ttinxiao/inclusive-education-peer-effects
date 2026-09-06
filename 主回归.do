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
* 3. 分组变量 0 / 1 / 2‑3 / 4+
*---------------------
gen disabled_group = .
replace disabled_group = 0 if disabled_count == 0
replace disabled_group = 1 if disabled_count == 1
replace disabled_group = 2 if disabled_count >=2 & disabled_count <=3
replace disabled_group = 3 if disabled_count >=4
label define dis_label 0 "No disabled" 1 "1 Disabled" 2 "2‑3 Disabled" 3 "4+ Disabled"
label values disabled_group dis_label
*---------------------
* 4. 仅保留非残疾学生
*---------------------
keep if disabled_student == 0
*---------------------
* 5. 因变量：raw + 主分析std标准化
*---------------------
local interaction_vars "b2801 b2802 b2803 b2804 b2805 b2806"
egen interaction_freq_raw = rowmean(`interaction_vars')
egen interaction_freq_std = std(interaction_freq_raw)
label var interaction_freq_std "亲子互动频率(标准化 mean=0 SD=1)"

local quality_vars "b2501 b2502"
egen quality_raw = rowmean(`quality_vars')
egen relationship_quality_std = std(quality_raw)
label var relationship_quality_std "亲子关系质量(标准化 mean=0 SD=1)"

gen investment_raw = b29
egen parental_investment_std = std(investment_raw)
label var parental_investment_std "父母投入感知(标准化 mean=0 SD=1)"


*---------------------
* 6. 控制变量
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
* 7. 剔除缺失值：使用*_std变量
*---------------------
drop if missing(parental_investment_std, interaction_freq_std, relationship_quality_std, ///
    gender, age, minority, only_child, rural, father_edu, mother_edu, ses, class_size, has_disabled)

*=========================================================================
* Table 3: 主回归——平均效应（std标准化因变量）
*=========================================================================
eststo clear
qui reg interaction_freq_std has_disabled gender age minority only_child rural father_edu mother_edu ses class_size i.schids, cluster(schids)
eststo model_baseline1
local coef_interaction = _b[has_disabled]
local se_interaction = _se[has_disabled]

qui reg relationship_quality_std has_disabled gender age minority only_child rural father_edu mother_edu ses class_size i.schids, cluster(schids)
eststo model_baseline2
local coef_quality = _b[has_disabled]
local se_quality = _se[has_disabled]

qui reg parental_investment_std has_disabled gender age minority only_child rural father_edu mother_edu ses class_size i.schids, cluster(schids)
eststo model_baseline3
local coef_investment = _b[has_disabled]
local se_investment = _se[has_disabled]

esttab model_baseline1 model_baseline2 model_baseline3 using "Table3_Baseline_Main_std.rtf", replace ///
    title("Table 3: Average Effect of Disabled Peers on Parent‑Child Relationships") ///
    mtitles("Interaction Frequency" "Relationship Quality" "Parental Investment") ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    coeflabels(has_disabled "Has Disabled Peers") ///
    keep(has_disabled) ///
    b ci nonumber compress ///
    addnotes("Notes: Outcome variables are standardized (mean=0, SD=1). Non‑disabled 7th‑grade students. Standard errors clustered at school level.")

*=========================================================================
* Table 4: 剂量效应（std标准化因变量）
*=========================================================================
eststo clear
eststo: reg interaction_freq_std i.disabled_group gender age minority only_child rural father_edu mother_edu ses class_size i.schids, cluster(schids)
eststo: reg relationship_quality_std i.disabled_group gender age minority only_child rural father_edu mother_edu ses class_size i.schids, cluster(schids)
eststo: reg parental_investment_std i.disabled_group gender age minority only_child rural father_edu mother_edu ses class_size i.schids, cluster(schids)

esttab using "Table4_Dosage_Effect_std.rtf", replace ///
    title("Table 4: Effects by Number of Disabled Peers") ///
    mtitles("Interaction Frequency" "Relationship Quality" "Parental Investment") ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    coeflabels(1.disabled_group "1 Disabled" 2.disabled_group "2‑3 Disabled" 3.disabled_group "4+ Disabled") ///
    keep(*.disabled_group) ///
    b ci nonumber compress ///
    addnotes("Notes: Outcome variables are standardized (mean=0, SD=1). Non‑disabled 7th‑grade students. Standard errors clustered at school level.")

*=========================================================================
* 效应量和最小可检测效应计算：必须在当前回归样本下对*_std取sd
*=========================================================================
sum interaction_freq_std
local sd_interaction = r(sd)
sum relationship_quality_std
local sd_quality = r(sd)
sum parental_investment_std
local sd_investment = r(sd)

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
di "所有表格和统计量已生成！"
