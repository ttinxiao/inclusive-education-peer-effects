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

*------------------------------------
* 1. 生成残疾学生标识
*------------------------------------
gen disabled_student = (bd1501==1 | bd1502==1 | bd1503==1 | bd1504==1 | bd1505==1 | bd1506==1 | bd1507==1)
replace disabled_student = 0 if missing(disabled_student)

*------------------------------------
* 2. 班级级数据（一个班级一行）
*------------------------------------
collapse (sum) disabled_student (count) ids, by(schids clsids)
rename disabled_student disabled_count  // 班级残疾人数
rename ids class_size                  // 班级人数

*------------------------------------
* 3. 按学校汇总统计
*------------------------------------
bysort schids: egen total_disabled_school = total(disabled_count)   // 全校残疾总数
bysort schids: egen num_classes_school = count(clsids)             // 全校班级数
gen disabled_per_class_school = total_disabled_school / num_classes_school  // 班均残疾人数

*------------------------------------
* 4.学校水平描述统计
*------------------------------------
bysort schids: keep if _n == 1

eststo clear
estpost tabstat total_disabled_school num_classes_school disabled_per_class_school, ///
    statistics(n mean sd min max) columns(statistics)

esttab using "Table_A1_学校水平残疾分布统计.rtf", replace ///
    cell("mean(fmt(3)) sd(fmt(3)) min(fmt(1)) max(fmt(1))") ///
    collabels("Mean" "SD" "Min" "Max") ///
    title("Table A1: School-Level Distribution of Disabled Students") ///
    nonumber nomtitle ///
    addnotes("Notes: Sample includes 7th-grade classes only.")

*------------------------------------
* 5. 班级残疾人数分布
*------------------------------------
clear all
set more off
cd "D:\导师\残疾伙伴与父母关系\Newceps"

use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta", keep(match) nogen  
merge m:1 clsids using "CEPS基线调查班级数据.dta", keep(match) nogen

keep if grade9 == 0

* 生成残疾学生（来自家长问卷 bd1501–bd1507）
gen disabled = (bd1501==1 | bd1502==1 | bd1503==1 | bd1504==1 | bd1505==1 | bd1506==1 | bd1507==1)
replace disabled = 0 if missing(disabled)

* 按班级汇总：每班残疾人数
collapse (sum) disabled_count=disabled, by(schids clsids)

*------------------------------------
* 分组：0 / 1 / 2-3 / 4+
*------------------------------------
gen disabled_group = .
replace disabled_group = 0 if disabled_count == 0
replace disabled_group = 1 if disabled_count == 1
replace disabled_group = 2 if disabled_count>=2 & disabled_count<=3
replace disabled_group = 3 if disabled_count>=4

label define dis ///
    0 "No disabled" ///
    1 "1 disabled" ///
    2 "2-3 disabled" ///
    3 "4+ disabled"
label values disabled_group dis

*------------------------------------
*  输出
*------------------------------------
eststo clear
estpost tab disabled_group

esttab using "Table_A2_班级残疾人数分布.rtf", replace ///
title("Table A2: Distribution of Disabled Students Across Classes") ///
cell("b(fmt(0)) pct(fmt(2))") ///
collabels("Freq." "Percent") ///
nonumber nomtitle ///
addnotes("Notes: Sample includes 7th-grade classes only.")

di "✅ Table A2 已成功输出！"