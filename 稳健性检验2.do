*=========================================================================
* 稳健性检验2：剔除极端班级规模（class_size <20 或 >60）
* 输出：样本量变化、剔除观测特征比较、回归结果
*=========================================================================
clear all
set more off

cd "D:\导师\残疾伙伴与父母关系\Newceps"

use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta", keep(match) nogen
merge m:1 clsids using "CEPS基线调查班级数据.dta", keep(match) nogen
keep if grade9 == 0

*---------------------
* 1. 生成残疾变量
*---------------------
gen disabled_student = (bd1501==1 | bd1502==1 | bd1503==1 | bd1504==1 | bd1505==1 | bd1506==1 | bd1507==1)
replace disabled_student = 0 if missing(disabled_student)
bysort schids clsids: egen disabled_count = total(disabled_student)
bysort schids clsids: egen class_size = count(ids)
gen has_disabled = (disabled_count >= 1)

* 只保留非残疾学生
keep if disabled_student == 0

*---------------------
* 2. 因变量：原始均值 + 标准化
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

*---------------------
* 4. 剔除缺失值（使用原始均值变量，确保与主分析一致）
*---------------------
drop if missing(interaction_freq_raw, quality_raw, investment_raw, ///
    gender, age, minority, only_child, rural, father_edu, mother_edu, ses, class_size, has_disabled)

* 保存全样本用于比较
tempfile full_sample
save `full_sample', replace

*---------------------
* 5. 极端班级规模标记与剔除
*---------------------
gen extreme = (class_size < 20 | class_size > 60) if !missing(class_size)

* 输出剔除前后的样本量
count
local N_full = r(N)
count if !extreme
local N_retained = r(N)
local N_excluded = `N_full' - `N_retained'
di "=== 班级规模限制样本变化 ==="
di "全样本量: `N_full'"
di "保留样本量 (20-60): `N_retained'"
di "剔除样本量 (<20 或 >60): `N_excluded'"
di "剔除比例: " %6.2f (`N_excluded' / `N_full') * 100 "%"

* 分别统计小于20和大于60的观测数
count if class_size < 20 & !missing(class_size)
di "班级规模 <20 的观测数: " r(N)
count if class_size > 60 & !missing(class_size)
di "班级规模 >60 的观测数: " r(N)

*---------------------
* 6. 被剔除观测与保留观测的特征比较表
*---------------------
local compare_vars "class_size gender age rural father_edu mother_edu ses minority only_child"

eststo clear
estpost summarize `compare_vars' if !extreme
eststo retained
estpost summarize `compare_vars' if extreme
eststo excluded

esttab retained excluded using "Table_X_Excluded_Characteristics.rtf", replace ///
    cells("mean(fmt(3)) sd(fmt(3))") ///
    mtitles("Retained (20-60)" "Excluded (<20 or >60)") ///
    title("Characteristics of Retained and Excluded Observations") ///
    nonumber ///
    addnotes("Notes: Mean and SD. Excluded observations refer to classrooms with fewer than 20 or more than 60 students.")

*---------------------
* 7. 对保留样本重新回归（使用标准化因变量）
*---------------------
keep if !extreme

local dependent_vars "interaction_freq_std relationship_quality_std parental_investment_std"
local independent_var "has_disabled"
local control_vars "gender age minority only_child rural father_edu mother_edu ses class_size"

estimates clear
local model_num = 1
foreach dep_var of local dependent_vars {
    reghdfe `dep_var' `independent_var' `control_vars', absorb(schids) vce(cluster schids)
    estimates store robust2_model_`model_num'
    local model_num = `model_num' + 1
}

*---------------------
* 8. 输出回归表格
*---------------------
esttab robust2_model_1 robust2_model_2 robust2_model_3 using "稳健性检验2_剔除极端班级.rtf", replace ///
    title("Table X2: Robustness Check: Excluding Extreme Class Sizes") ///
    b(3) se(3) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("N" "Adj R-squared")) ///
    mlabels("Parent-Child Interaction" "Relationship Quality" "Parental Investment") ///
    addnotes("Notes: Outcome variables are standardized (mean=0, SD=1). Classrooms with size <20 or >60 are excluded. School fixed-effects and full set of controls included. Standard errors clustered at school level. * p<0.1, ** p<0.05, *** p<0.01")

di "稳健性检验2 运行完成！"
