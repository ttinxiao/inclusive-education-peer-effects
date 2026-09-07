
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
* 残疾变量
gen disabled_student = (bd1501==1|bd1502==1|bd1503==1|bd1504==1|bd1505==1|bd1506==1|bd1507==1)
replace disabled_student = 0 if missing(disabled_student)

bysort clsids: egen disabled_count = total(disabled_student)
gen has_disabled = (disabled_count >= 1)
label var has_disabled "班级中是否有残疾同伴 (1=是)"

* 控制变量
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
bysort clsids: egen class_size = count(ids)
label var class_size "班级规模"

* 因变量
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


* 自己本身没有残疾的学生
*----------------------
keep if disabled_student == 0

* 删除结果变量和控制变量缺失的观测
drop if missing(parental_investment_std, interaction_freq_std, relationship_quality_std, ///
    gender, age, minority, only_child, rural, father_edu, mother_edu, ses, class_size, has_disabled)

*--------------------------------------------------------------------
* 5. 执行平衡性检验 
*--------------------------------------------------------------------
local covars gender age minority only_child rural father_edu mother_edu ses class_size

// 先检查是否安装 reghdfe
capture which reghdfe
if _rc {
    ssc install reghdfe
}

eststo clear
eststo: reghdfe has_disabled `covars', absorb(schids) vce(cluster schids)
* 对全部协变量做联合F检验
test `covars'
estadd scalar F_joint = r(F)
estadd scalar p_joint = r(p)
estadd scalar r2_w = e(r2_within)

* 输出时包含 F 统计量和 p 值
esttab using "平衡性检验结果.rtf", replace ///
       b(%9.3f) se(%9.3f) star(* 0.1 ** 0.05 *** 0.01) ///
       title("协变量平衡性检验") ///
       mtitles("模型") ///
     stats(N r2_a r2_w F_joint p_joint, labels("观测值" "调整后R方" "组内R方" "F统计量" "p值(联合F检验)")) ///
       nonumber ///
       addnotes("注：模型吸收了学校固定效应，标准误在学校层面聚类。p 值来自所有协变量的联合 F 检验。")