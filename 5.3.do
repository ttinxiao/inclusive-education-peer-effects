//控制学校归属感后的回归
clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"
use "七年级非残疾学生数据_完整变量.dta", clear

// 定义变量
local dependent_vars "interaction_freq relationship_quality parental_investment"
local core_var "has_disabled"
local control_vars "gender age minority only_child mother_edu father_edu family_eco rural class_size"

// 生成school_belonging
egen school_belonging = rowmean(c1706 c1707 c1708 c1709 c1710)

// 估计三个模型（控制school_belonging）
estimates clear
local model_num = 1
foreach dep_var of local dependent_vars {
    areg `dep_var' `core_var' school_belonging `control_vars', absorb(schids) robust cluster(schids)
    estimates store mediate_`model_num'
    display "=== 模型`model_num`：因变量=`dep_var' ==="
    display "has_disabled系数：" %5.3f _b[`core_var']
    display "school_belonging系数：" %5.3f _b[school_belonging]
    local model_num = `model_num' + 1
}

// 输出表格
esttab mediate_1 mediate_2 mediate_3 using "机制分析-中介检验.rtf", replace ///
    title("表5-3 控制学校归属感后的基准回归（中介检验）") ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("样本量" "调整后R²")) ///
    varlabels(`core_var' "班级有残疾学生" school_belonging "学校归属感" _cons "常数项") ///
    mlabels("亲子互动频率" "亲子关系质量" "父母投入感知") ///
    addnotes("注：1. 标准误按学校层面聚类；2. 控制变量包括：性别、年龄、少数民族、独生子女、父母教育年限、家庭经济状况、农村户口、班级规模；3. *p<0.1, **p<0.05, ***p<0.01")