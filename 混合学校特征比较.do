*=========================================================================
* 项目: 统计最终回归样本中同时包含有残疾和无残疾班级的学校数量
*=========================================================================
clear all
set more off
cd "D:\导师\残疾伙伴与父母关系\Newceps"
use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta", keep(match) nogenerate
merge m:1 clsids using "CEPS基线调查班级数据.dta", keep(match) nogenerate
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
* 3. 分组变量（可选，仅用于其他分析）
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

* 保存学生水平分析样本，用于后续统计学生数
tempfile student_analysis
save `student_analysis', replace

*-------------------------------------------------------------------------
* 8. 降维至班级水平，并识别混合学校
*-------------------------------------------------------------------------
collapse (max) has_disabled, by(schids clsids)

* 计算每所学校内 has_disabled 的最小值和最大值
bysort schids: egen min_has_disabled = min(has_disabled)
bysort schids: egen max_has_disabled = max(has_disabled)

* 统计每所学校在当前分析样本中的班级数量
bysort schids: gen classes_per_school = _N

* 定义学校类型
gen school_type = .
replace school_type = 1 if min_has_disabled == 0 & max_has_disabled == 1  // 混合学校
replace school_type = 2 if min_has_disabled == 1 & max_has_disabled == 1  // 仅有融合班级
replace school_type = 3 if min_has_disabled == 0 & max_has_disabled == 0  // 仅有非融合班级

label define sch_lbl 1 "Both Types (Mixed)" 2 "Only Inclusive Classes" 3 "Only Non-Inclusive Classes"
label values school_type sch_lbl

* 降维至学校水平
collapse (first) school_type classes_per_school, by(schids)

* 保存学校类型数据，稍后合并回学生数据
tempfile school_type_data
save `school_type_data', replace

*-------------------------------------------------------------------------
* 9. 统计混合学校的数量、班级数和学生数
*-------------------------------------------------------------------------
* 学校数量和班级数直接从学校水平数据获得
quietly count if school_type == 1
local n_mixed_schools = r(N)

quietly sum classes_per_school if school_type == 1
local n_mixed_classes = r(sum)

* 重新加载学生水平数据，合并学校类型
use `student_analysis', clear
merge m:1 schids using `school_type_data', nogen keep(match)

* 统计混合学校中的学生总数
quietly count if school_type == 1
local n_mixed_students = r(N)

* 输出结果
di "========================================================="
di "          混合学校识别结果 (最终回归样本)               "
di "========================================================="
di "混合学校数量: " `n_mixed_schools'
di "混合学校中的班级总数: " `n_mixed_classes'
di "混合学校中的学生总数: " `n_mixed_students'
di "========================================================="

*-------------------------------------------------------------------------
* 10. 标记混合学校学生并生成比较表
*-------------------------------------------------------------------------
use `student_analysis', clear
merge m:1 schids using `school_type_data', nogen keep(match)

* 生成混合学校标记
gen mixed_school = (school_type == 1)
label var mixed_school "混合学校学生(1=是)"

* 定义用于比较的关键变量
local compare_vars "gender age minority only_child rural father_edu mother_edu ses class_size"

* 先对每个变量做两样本 t 检验，提取 p 值
foreach var of local compare_vars {
    quietly ttest `var', by(mixed_school)
    local p_`var' : display %5.3f r(p)
}
* 生成分组描述统计表
eststo clear
estpost summarize `compare_vars' if mixed_school == 1
eststo mixed
estpost summarize `compare_vars' if mixed_school == 0
eststo nonmixed

* 输出表格
esttab mixed nonmixed using "Table_A3_混合学校与非混合学校学生特征对比.rtf", replace ///
    cells("mean(fmt(2)) sd(fmt(2))") ///
    mtitles("Mixed-school students" "Other students") ///
    title("Table A3: Characteristics of Students in Mixed versus Non-Mixed Schools") ///
    nonumber ///
    addnotes("Notes: Means and standard deviations. Mixed-school students are those in schools containing both inclusive and non-inclusive classrooms. P-values from two-sample t-tests: gender p=`p_gender', age p=`p_age', minority p=`p_minority', only child p=`p_only_child', rural p=`p_rural', father education p=`p_father_edu', mother education p=`p_mother_edu', SES p=`p_ses', class size p=`p_class_size'.")
