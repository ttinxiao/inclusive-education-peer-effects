*=========================================================================
* 稳健性检验2：剔除极端班级规模（class_size <20 或 >60）
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

bysort schids clsids: egen class_disabled_count = total(disabled_student)
bysort schids clsids: egen class_size = count(ids)
gen has_disabled = (class_disabled_count >= 1)

*---------------------
* 2. 只保留非残疾学生
*---------------------
keep if disabled_student == 0

*---------------------
* 3. 因变量
*---------------------
egen interaction_freq = rowmean(b2801 b2802 b2803 b2804 b2805 b2806)
egen relationship_quality = rowmean(b2501 b2502)
gen parental_investment = b29

*---------------------
* 4. 控制变量
*---------------------
gen gender = stsex
gen age = 2013 - a02a
gen minority = (a03 != 1)
gen only_child = (stonly == 1)
gen mother_edu = stmedu
gen father_edu = stfedu
gen family_eco = steco_5c
gen rural = (sthktype == 1)

*---------------------
* 5. 剔除缺失值
*---------------------
drop if missing(interaction_freq, relationship_quality, parental_investment, ///
gender, age, minority, only_child, mother_edu, father_edu, family_eco, rural, class_size, has_disabled)

*---------------------
* 6. 剔除极端班级规模
*---------------------
drop if class_size < 20 | class_size > 60
count
display "剔除极端班级后样本量：" r(N)

*---------------------
* 7. 回归
*---------------------
local dependent_vars "interaction_freq relationship_quality parental_investment"
local independent_var "has_disabled"
local control_vars "gender age minority only_child mother_edu father_edu family_eco rural class_size"

estimates clear
local model_num = 1
foreach dep_var of local dependent_vars {
    areg `dep_var' `independent_var' `control_vars', absorb(schids) robust cluster(schids)
    estimates store robust2_model_`model_num'
    local model_num = `model_num' + 1
}

*---------------------
* 8. 输出英文表格
*---------------------
esttab robust2_model_1 robust2_model_2 robust2_model_3 using "稳健性检验2_剔除极端班级.rtf", replace ///
title("Table X2: Robustness Check: Excluding Extreme Class Sizes") ///
b(3) se(3) ///
star(* 0.1 ** 0.05 *** 0.01) ///
stats(N r2_a, fmt(0 3) labels("N" "Adj R-squared")) ///
varlabels( _cons "Constant") ///
mlabels("Parent-Child Interaction" "Relationship Quality" "Parental Investment") ///
addnotes("Notes: Standard errors clustered at school level. * p<0.1, ** p<0.05, *** p<0.01")

di "✅ 稳健性检验2 运行完成！"