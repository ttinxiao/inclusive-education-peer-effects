
clear all
set more off

// 设置工作路径
cd "D:\导师\残疾伙伴与父母关系\Newceps"

*-------------------------------------------------
* 2. 数据导入与合并 
*-------------------------------------------------
use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta"
keep if _merge == 3
drop _merge

merge m:1 clsids using "CEPS基线调查班级数据.dta"
keep if _merge == 3
drop _merge

*-------------------------------------------------
* 3. 数据清洗与筛选 )
*-------------------------------------------------
keep if grade9 == 0  // 仅保留七年级


*-------------------------------------------------
* 4. 核心变量生成
*-------------------------------------------------
gen disabled_student = (bd1501==1 | bd1502==1 | bd1503==1 | bd1504==1 | bd1505==1 | bd1506==1 | bd1507==1) if !missing(bd1501)
recode disabled_student (.=0)
bysort clsids: egen disabled_count = total(disabled_student)
gen has_disabled = (disabled_count >= 1)
label var has_disabled "班级中是否有残疾同伴 (1=是)"

gen gender = stsex
label var gender "学生性别 (1=男)"
gen age = 2013 - a02a if !missing(a02a)
label var age "学生年龄"
gen only_child = (stonly==1) if !missing(stonly)
recode only_child (.=0)
label var only_child "是否独生子女 (1=是)"
gen rural = (sthktype == 1) if !missing(sthktype)
label var rural "是否农业户口 (1=是)"
gen father_edu = stfedu
label var father_edu "父亲受教育水平"
gen mother_edu = stmedu
label var mother_edu "母亲受教育水平"
gen ses = steco_5c
label var ses "家庭SES(5分位)"
bysort clsids: egen class_size = count(ids)
label var class_size "班级规模"

* 自己本身没有残疾的学生
*----------------------
keep if disabled_student == 0

*--------------------------------------------------------------------
* 5. 执行平衡性检验 
*--------------------------------------------------------------------
local covars gender age only_child rural father_edu mother_edu ses class_size

// 先检查是否安装 reghdfe
capture which reghdfe
if _rc {
    ssc install reghdfe
}

eststo clear
eststo: reghdfe has_disabled `covars', absorb(schids) vce(cluster schids)

*--------------------------------------------------------------------
* 6. 结果输出
*--------------------------------------------------------------------
esttab using "平衡性检验结果_回归法.rtf", replace ///
       b(%9.3f) se(%9.3f) star(* 0.1 ** 0.05 *** 0.01) ///
       title("协变量平衡性检验") ///
       mtitles("模型") ///
       stats(N r2_a r2_within, labels("观测值" "调整后R方" "组内R方")) ///
       nonumber ///
       addnotes("注：模型吸收了学校固定效应，标准误在学校层面聚类。")

di "平衡性检验完成！结果已输出到文件: 平衡性检验结果_回归法.rtf"