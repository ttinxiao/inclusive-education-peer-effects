// 加载基线回归使用的完整数据
clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"
use "七年级非残疾学生数据_完整变量.dta", clear

// 定义核心变量组
local dependent_vars "interaction_freq relationship_quality parental_investment"  // 3个亲子关系因变量
local independent_var "has_disabled"  // 核心解释变量：班级是否有残疾学生
local control_vars "gender age minority only_child mother_edu father_edu family_eco rural class_size"  // 控制变量组

// 步骤1：剔除极端班级规模样本
drop if class_size < 20 | class_size > 60
count  // 查看剔除后样本量
display "剔除极端班级后样本量：" %6.0f r(N)

// 步骤2：在筛选后样本中重新进行基线回归
estimates clear
local model_num = 1
foreach dep_var of local dependent_vars {
    areg `dep_var' `independent_var' `control_vars', absorb(schids) robust cluster(schids)
    estimates store robust2_model_`model_num'  // 存储稳健性检验结果（robust2）
    
    // 核心结果
    display "=== 稳健性检验2-模型`model_num`：因变量=`dep_var` ==="
    display "班级有残疾学生系数：" %5.3f _b[`independent_var'] ", p值：" %5.3f 2*normprob(-abs(_b[`independent_var']/_se[`independent_var']))
    local model_num = `model_num' + 1
}

// 步骤3：输出剔除异常样本后的结果表
esttab robust2_model_1 robust2_model_2 robust2_model_3 using "稳健性检验2_剔除极端班级.rtf", replace ///
    title("表X2 稳健性检验：剔除极端班级规模样本") ///
    b(3) se(3) ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("样本量" "调整后R²")) ///
    varlabels(`independent_var' "班级有残疾学生" _cons "常数项") ///
    mlabels("亲子互动频率" "亲子关系质量" "父母投入感知")