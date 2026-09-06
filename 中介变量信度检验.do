clear all
set more off
cd "D:\导师\残疾伙伴与父母关系\Newceps"

use "CEPS基线调查学生数据.dta", clear
merge 1:1 ids using "CEPS基线调查家长数据.dta", keep(match) nogen
merge m:1 clsids using "CEPS基线调查班级数据.dta", keep(match) nogen

keep if grade9 == 0

*---------------------
* 1. 残疾学生变量
*---------------------
gen disabled_student = (bd1501==1 | bd1502==1 | bd1503==1 | bd1504==1 | bd1505==1 | bd1506==1 | bd1507==1)
replace disabled_student = 0 if missing(disabled_student)

bysort schids clsids: egen class_disabled_count = total(disabled_student)
bysort schids clsids: egen class_size = count(ids)
gen has_disabled = (class_disabled_count >= 1)

keep if disabled_student == 0

*=========================================================================
*  信度检验
*=========================================================================

log using "信度检验结果.rtf", replace text

* 1. 抑郁
di "====================================="
di "1. 抑郁量表信度"
alpha a1801 a1802 a1803 a1804 a1805, item detail

* 2. 学业压力
di "====================================="
di "2. 学业压力信度"
alpha c1101 c1102 c1103, item detail

* 3. 自我效能感
di "====================================="
di "3. 自我效能感信度"
alpha a1201 a1202 a1203 a1204 a1205 a1206 a1207, item detail

* 4. 学校归属感
di "====================================="
di "4. 学校归属感信度"
alpha c1706 c1707 c1708 c1709 c1710, item detail

* 5. 学校疏离感
di "====================================="
di "5. 学校疏离感信度"
alpha c1711 c1712, item detail

* 6. 亲子沟通
di "====================================="
di "6. 亲子沟通信度"
alpha ba1401 ba1402 ba1403 ba1404 ba1405, item detail

log close

di "✅ 信度检验已成功输出到：信度检验结果.rtf"
