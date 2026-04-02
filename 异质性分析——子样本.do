// =========================================================================
// 异质性分析：子样本法
// =========================================================================
clear all
set more off
cd "D:\导师\残疾伙伴与父母关系\Newceps"

// --- 1. 数据准备 ---
use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta", keep(match) nogen
merge m:1 clsids using "CEPS基线调查班级数据.dta", keep(match) nogen

keep if grade9 == 0

// --- 2. 核心变量生成 ---
gen disabled_student = (bd1501==1 | bd1502==1 | bd1503==1 | bd1504==1 | bd1505==1 | bd1506==1 | bd1507==1)
replace disabled_student = 0 if missing(disabled_student)

bysort schids clsids: egen class_disabled_count = total(disabled_student)
bysort schids clsids: egen class_size = count(ids)
gen has_disabled = (class_disabled_count >= 1)

keep if disabled_student == 0


// --- 3. 因变量、控制变量和异质性分组变量生成 ---

// 因变量
egen interaction_freq = rowmean(b2801 b2802 b2803 b2804 b2805 b2806)
egen relationship_quality = rowmean(b2501 b2502)
gen parental_investment = b29

// 控制变量
gen age = 2013 - a02a
gen minority = (a03 != 1)
gen mother_edu = stmedu
gen father_edu = stfedu
gen family_eco = steco_5c
gen rural = (sthktype == 1)

// 异质性分组变量 (在处理缺失值之前生成)
gen low_SES = (family_eco <= 2) if !missing(family_eco)
label var low_SES "是否为低SES家庭（1=是，0=否）"

gen is_only_child = (stonly == 1) if !missing(stonly)
label var is_only_child "是否独生子女（1=是，0=否）"

gen is_female = (stsex == 0) if !missing(stsex)
label var is_female "是否为女性（1=是，0=否）"

// --- 4. 定义变量宏和统一处理缺失值 ---
local dependent_vars "interaction_freq relationship_quality parental_investment"
local core_var "has_disabled"
local controls "age minority mother_edu father_edu family_eco rural class_size"

// 统一处理缺失值，确保所有回归使用同一批完整样本
drop if missing(interaction_freq, relationship_quality, parental_investment, has_disabled)
drop if missing(age, minority, mother_edu, father_edu, family_eco, rural, class_size)
drop if missing(low_SES, is_only_child, is_female)


*-----------------------------------------
* (1) 家庭经济水平 (SES) 异质性
*-----------------------------------------
estimates clear
local model_num = 1
foreach dep of local dependent_vars {
    // 低 SES 组
    areg `dep' `core_var' `controls' if low_SES==1, absorb(schids) robust cluster(schids)
    estimates store hetero_low_`model_num'
    
    // 中高 SES 组
    areg `dep' `core_var' `controls' if low_SES==0, absorb(schids) robust cluster(schids)
    estimates store hetero_high_`model_num'
    
    local model_num = `model_num' + 1
}

esttab hetero_low_1 hetero_high_1 hetero_low_2 hetero_high_2 hetero_low_3 hetero_high_3 using "异质性_SES_子样本.rtf", replace ///
    title("异质性分析（子样本法）：家庭经济水平") ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) keep(`core_var') ///
    stats(N, fmt(0) labels("样本量")) ///
    mlabels("互动频率(低SES)" "互动频率(中高SES)" "关系质量(低SES)" "关系质量(中高SES)" "投入感知(低SES)" "投入感知(中高SES)", span) ///
    addnotes("注：此表展示在不同SES子样本中接触残疾同伴对亲子关系的影响。仅展示核心变量系数。")

*-----------------------------------------
* (2) 是否独生子女 (Only Child) 异质性
*-----------------------------------------
estimates clear
local model_num = 1
foreach dep of local dependent_vars {
    // 独生子女组
    areg `dep' `core_var' `controls' if is_only_child==1, absorb(schids) robust cluster(schids)
    estimates store hetero_only_`model_num'
    
    // 非独生子女组
    areg `dep' `core_var' `controls' if is_only_child==0, absorb(schids) robust cluster(schids)
    estimates store hetero_nononly_`model_num'  // 【【【 已修正此处的拼写错误 】】】
    
    local model_num = `model_num' + 1
}

// --- 针对 是否独生子女 ---
esttab hetero_nononly_1 hetero_only_1 hetero_nononly_2 hetero_only_2 hetero_nononly_3 hetero_only_3 using "异质性_独生_子样本.rtf", replace ///
    title("异质性分析（子样本法）：是否独生子女") ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) keep(`core_var') ///
    stats(N, fmt(0) labels("样本量")) ///
    mlabels("互动频率(非独生)" "互动频率(独生)" "关系质量(非独生)" "关系质量(独生)" "投入感知(非独生)" "投入感知(独生)", span) ///
    addnotes("注：此表展示在不同是否独生子女样本中接触残疾同伴对亲子关系的影响。仅展示核心变量系数。")


*-----------------------------------------
* (3) 性别 (Gender) 异质性
*-----------------------------------------
estimates clear
local model_num = 1
foreach dep of local dependent_vars {
    // 女性组
    areg `dep' `core_var' `controls' if is_female==1, absorb(schids) robust cluster(schids)
    estimates store hetero_female_`model_num'
    
    // 男性组
    areg `dep' `core_var' `controls' if is_female==0, absorb(schids) robust cluster(schids)
    estimates store hetero_male_`model_num'
    
    local model_num = `model_num' + 1
}

// --- 针对 性别异质性 ---
esttab hetero_female_1 hetero_male_1 hetero_female_2 hetero_male_2 hetero_female_3 hetero_male_3 using "异质性_性别_子样本.rtf", replace ///
    title("异质性分析（子样本法）：学生性别") ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) keep(`core_var') ///
    stats(N, fmt(0) labels("样本量")) ///
    mlabels("互动频率(女性)" "互动频率(男性)" "关系质量(女性)" "关系质量(男性)" "投入感知(女性)" "投入感知(男性)", span) ///
    addnotes("注：此表展示在不同性别子样本中接触残疾同伴对亲子关系的影响。仅展示核心变量系数。")

di "✅ 异质性分析（子样本法）代码已完成，并成功生成三张独立的RTF表格！"

