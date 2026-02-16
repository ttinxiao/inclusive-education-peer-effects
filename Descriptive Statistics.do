clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"
use "七年级非残疾学生数据_完整变量.dta", clear

// 定义核心变量组
local dependent_vars "interaction_freq relationship_quality parental_investment"
local independent_var "has_disabled"
local control_vars "gender age minority only_child mother_edu father_edu family_eco rural class_size"

// ============================================================
label var interaction_freq "亲子互动频率"
label var relationship_quality "亲子关系质量"  
label var parental_investment "父母投入感知"
label var has_disabled "班级是否有残疾学生（1=有）"
label var disabled_peer_share "残疾学生比例"
label var gender "性别（1=男）"
label var age "年龄"
label var minority "少数民族（1=是）"
label var only_child "独生子女（1=是）"
label var mother_edu "母亲受教育年限"
label var father_edu "父亲受教育年限"
label var family_eco "家庭经济状况"
label var rural "农村户口（1=是）"
label var class_size "班级规模"

// 先筛选出回归所用的完整样本
// ============================================================
// 生成样本筛选标识：仅保留所有回归变量（含吸收变量schids）无缺失的观测
gen reg_sample = 1  // 先标记所有观测为有效
// 检查回归核心变量是否有缺失
foreach var of varlist `dependent_vars' `independent_var' `control_vars' schids {
    replace reg_sample = . if mi(`var')  // 只要任意变量缺失，标记为无效
}
// 保留仅回归可用的样本
keep if reg_sample == 1  
drop reg_sample  // 删除临时标识变量

// ============================================================
// 表1：主要变量描述性统计
estpost summarize `dependent_vars' `independent_var' disabled_peer_share `control_vars', detail
esttab using "表1_描述性统计.rtf", replace ///
    cells("count(fmt(0) label(N)) mean(fmt(3) label(均值)) sd(fmt(3) label(标准差)) min(fmt(3) label(最小值)) max(fmt(3) label(最大值))") ///
    title("表1 描述性统计（回归样本）") ///  // 建议修改标题，标注是回归样本
    nonumber nomtitle ///
    addnotes("注：1. 连续变量报告均值、标准差、最小值和最大值；二元变量报告均值（即比例为1的百分比）。")

*/