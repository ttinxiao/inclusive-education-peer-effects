*=========================================================================
* 稳健性检验4：班级固定效应（验证基准模型正确）
*=========================================================================

clear all
set more off
cd "D:\导师\残疾伙伴与父母关系\Newceps"

use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta", keep(match) nogen
merge m:1 clsids using "CEPS基线调查班级数据.dta", keep(match) nogen

keep if grade9 == 0

*---------------------
* 1. 生成所有变量
*---------------------
gen disabled_student = (bd1501==1 | bd1502==1 | bd1503==1 | bd1504==1 | bd1505==1 | bd1506==1 | bd1507==1)
replace disabled_student = 0 if missing(disabled_student)

bysort schids clsids: egen class_disabled_count = total(disabled_student)
bysort schids clsids: egen class_size = count(ids)
gen has_disabled = (class_disabled_count >= 1)

keep if disabled_student == 0

* 因变量
egen interaction_freq = rowmean(b2801 b2802 b2803 b2804 b2805 b2806)
egen relationship_quality = rowmean(b2501 b2502)
gen parental_investment = b29

* 控制变量
gen gender = stsex
gen age = 2013 - a02a
gen minority = (a03 != 1)
gen only_child = (stonly == 1)
gen mother_edu = stmedu
gen father_edu = stfedu
gen family_eco = steco_5c
gen rural = (sthktype == 1)

* 剔除缺失值
drop if missing(interaction_freq, relationship_quality, parental_investment, ///
gender, age, minority, only_child, mother_edu, father_edu, family_eco, rural, class_size, has_disabled)

*---------------------
* 2. 稳健性4：班级固定效应
*---------------------
local dependent_vars "interaction_freq relationship_quality parental_investment"
local independent_var "has_disabled"
local control_vars "gender age minority only_child mother_edu father_edu family_eco rural class_size"

estimates clear
local model_num = 1
foreach dep_var of local dependent_vars {
    areg `dep_var' `independent_var' `control_vars', absorb(clsids) robust cluster(schids)
    estimates store robust4_model_`model_num'
    local model_num = `model_num' + 1
}

*---------------------
* 3. 输出表格
*---------------------
esttab robust4_model_1 robust4_model_2 robust4_model_3 using "稳健性检验4_替换固定效应.rtf", replace ///
title("Table X4: Classroom Fixed Effects") ///
b(3) se(3) ///
star(* 0.1 ** 0.05 *** 0.01) ///
stats(N r2_a, fmt(0 3) labels("N" "Adj R-squared")) ///
mlabels("Parent-Child Interaction" "Relationship Quality" "Parental Investment") ///
addnotes("Notes: Estimates absorbed by classroom fixed effects. School FE is preferred.")

di "✅ 稳健性检验4 运行完成！"