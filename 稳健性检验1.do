clear all
set more off
cd "D:\导师\残疾伙伴与父母关系\Newceps"

use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta", keep(match) nogen
merge m:1 clsids using "CEPS基线调查班级数据.dta", keep(match) nogen

keep if grade9 == 0

*---------------------
* 1. 定义残疾学生
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
replace disabled_ratio = 0 if missing(disabled_ratio)

*---------------------
* 3. 只保留非残疾学生
*---------------------
keep if disabled_student == 0

*---------------------
* 4. 因变量：原始均值 + 标准化
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
* 5. 控制变量
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
* 6. 剔除缺失值
*---------------------
drop if missing(parental_investment_std, interaction_freq_std, relationship_quality_std, ///
    gender, age, minority, only_child, rural, father_edu, mother_edu, ses, class_size, has_disabled)

*=========================================================================
*  稳健性检验1：替换核心解释变量 → disabled_ratio（连续比例）
*=========================================================================
local dependent_vars "interaction_freq_std relationship_quality_std parental_investment_std"
local control_vars "gender age minority only_child rural father_edu mother_edu ses class_size"

estimates clear
local model_num = 1
foreach dep_var of local dependent_vars {
    reghdfe `dep_var' disabled_ratio `control_vars', absorb(schids) vce(cluster schids)
    estimates store robust1_model_`model_num'
    local model_num = `model_num' + 1
}

*---------------------
* 输出 RTF 表格
*---------------------
esttab robust1_model_1 robust1_model_2 robust1_model_3 using "稳健性检验1_替换解释变量.rtf", replace ///
    title("Table X1: Robustness Check Using Disabled Student Ratio (Standardized Outcomes)") ///
    b(3) se(3) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("N" "Adj R-squared")) ///
    varlabels(_cons "Constant") ///
    mlabels("Parent-Child Interaction" "Relationship Quality" "Parental Investment") ///
    addnotes("Notes: Standard errors clustered at school level. Controls included. * p<0.1, ** p<0.05, *** p<0.01")

di "稳健性检验1 运行完成！"