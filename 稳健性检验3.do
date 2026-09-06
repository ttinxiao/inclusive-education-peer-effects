*=========================================================================
* 稳健性检验3：Placebo Test 安慰剂检验（单次置换，班级层面随机分配）
*=========================================================================
clear all
set more off
cd "D:\导师\残疾伙伴与父母关系\Newceps"
use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta", keep(match) nogen
merge m:1 clsids using "CEPS基线调查班级数据.dta", keep(match) nogen
keep if grade9 == 0

*---------------------
* 生成变量
*---------------------
gen disabled_student = (bd1501==1 | bd1502==1 | bd1503==1 | bd1504==1 | bd1505==1 | bd1506==1 | bd1507==1)
replace disabled_student = 0 if missing(disabled_student)
bysort schids clsids: egen class_disabled_count = total(disabled_student)
bysort schids clsids: egen class_size = count(ids)
gen has_disabled = (class_disabled_count >= 1)
keep if disabled_student == 0

*---------------------
* 因变量：raw + std标准化，与主回归保持一致
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
* 控制变量
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
* 剔除缺失值：使用_std变量
*---------------------
drop if missing(interaction_freq_std, relationship_quality_std, parental_investment_std, ///
gender, age, minority, only_child, mother_edu, father_edu, ses, rural, class_size, has_disabled)

*---------------------
* 安慰剂构造：班级层面置换，保持真实has_disabled班级数量不变
*---------------------
tempfile student_data
save `student_data', replace

*压缩到班级层面
preserve
collapse (first) has_disabled, by(clsids)
set seed 12345
gen rand = runiform()
sort rand
* 保持真实处理班级数目不变
count if has_disabled == 1
local n_treat = r(N)
gen placebo_disabled = (_n <= `n_treat')
keep clsids placebo_disabled
tempfile placebo_class
save `placebo_class', replace
restore

* 将安慰剂处理匹配回学生数据，同一个班级placebo_disabled完全相同
merge m:1 clsids using `placebo_class', keepusing(placebo_disabled) keep(match) nogen

*---------------------
* 回归 reghdfe
*---------------------
local dependent_vars "interaction_freq_std relationship_quality_std parental_investment_std"
local control_vars "gender age minority only_child mother_edu father_edu ses rural class_size"
estimates clear
local model_num = 1
foreach dep_var of local dependent_vars {
    reghdfe `dep_var' placebo_disabled `control_vars', absorb(schids) vce(cluster schids)
    estimates store robust3_model_`model_num'
    local model_num = `model_num' + 1
}

*---------------------
* 输出英文表格
*---------------------
esttab robust3_model_1 robust3_model_2 robust3_model_3 using "稳健性检验3_安慰剂检验.rtf", replace ///
title("Table X3: Single Draw Placebo Test") ///
b(3) se(3) ///
star(* 0.1 ** 0.05 *** 0.01) ///
stats(N r2_a, fmt(0 3) labels("N" "Adj R‑squared")) ///
mlabels("Parent‑Child Interaction" "Relationship Quality" "Parental Investment") ///
addnotes("Notes: Outcome variables are standardized (mean=0, SD=1). Placebo treatment is randomly assigned at classroom level, holding the number of treated classrooms identical to real data. School fixed‑effects and full controls included. Standard errors clustered at school level. * p<0.1, ** p<0.05, *** p<0.01")

di "稳健性检验3（单次安慰剂）运行完成！"
