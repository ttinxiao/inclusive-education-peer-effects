// 基础环境设置
clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"  

// 加载原始数据
use "七年级学生.dta", clear
describe  // 查看数据结构
count  // 查看总样本量

// 核心解释变量构建：残疾学生标识与班级残疾特征
//识别残疾学生（基于CEPS残疾类型变量bd1501-bd1507，任一为1则视为残疾）
local disability_vars "bd1501 bd1502 bd1503 bd1504 bd1505 bd1506 bd1507"
egen is_disabled = rowmax(`disability_vars')  // 行最大值：有任一残疾类型则为1
replace is_disabled = 0 if missing(is_disabled)  // 缺失值视为非残疾（0）
label define is_disabled_lbl 0 "非残疾学生" 1 "残疾学生"
label values is_disabled is_disabled_lbl
label var is_disabled "学生是否残疾"
tab is_disabled, missing  // 验证残疾学生占比

// 班级层面残疾特征（核心分组变量）
// 班级是否有残疾学生
bysort schids clsids: egen class_disabled_count = sum(is_disabled)  // 班级残疾学生数
gen has_disabled = (class_disabled_count > 0)  // 有1个及以上残疾学生=1
label define has_disabled_lbl 0 "无残疾学生班级" 1 "有残疾学生班级"
label values has_disabled has_disabled_lbl
label var has_disabled "班级是否有残疾学生"
tab has_disabled, missing  // 验证两组班级分布是否平衡

// 班级残疾学生比例
bysort schids clsids: egen class_size = count(ids)  // 班级总人数（剔除缺失学生ID）
gen disabled_peer_share = class_disabled_count / class_size  // 残疾学生比例
label var disabled_peer_share "班级残疾学生比例"
sum disabled_peer_share, detail  // 查看比例分布

// 样本筛选：保留非残疾学生（研究对象为非残疾学生的亲子关系）
keep if is_disabled == 0  // 剔除残疾学生样本
count  // 记录筛选后样本量
tab has_disabled, missing  // 再次验证筛选后两组班级的样本分布

// 保存中间数据避免重复处理
save "七年级非残疾学生数据_核心变量.dta", replace