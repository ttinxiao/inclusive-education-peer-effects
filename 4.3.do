// 步骤1：重新加载完整数据
use "七年级非残疾学生数据_完整变量.dta", clear

// 定义核心变量组
local dependent_vars "interaction_freq relationship_quality parental_investment"  // 3个亲子关系因变量
local independent_var "has_disabled"  // 核心解释变量：班级是否有残疾学生
local control_vars "gender age minority only_child mother_edu father_edu family_eco rural class_size"  // 控制变量组


// 步骤2：生成虚构的"班级有残疾学生"变量（placebo_disabled）
set seed 12345  // 设置随机种子，确保结果可复现
bysort schids clsids: gen placebo_disabled = runiform() > 0.5  // 按班级随机分配0/1（概率各50%，与真实变量分布近似）
label var placebo_disabled "虚构的班级有残疾学生（安慰剂）"

// 步骤3：用虚构变量重新回归（模型设定与基线一致）
estimates clear
local model_num = 1
foreach dep_var of local dependent_vars {
    areg `dep_var' placebo_disabled `control_vars', absorb(schids) robust cluster(schids)
    estimates store robust3_model_`model_num'  // 存储安慰剂检验结果（标记为robust3）
    // 输出核心结果
    display "=== 稳健性检验3-模型`model_num`：因变量=`dep_var` ==="
    display "虚构变量系数：" %5.3f _b[placebo_disabled] ", p值：" %5.3f 2*normprob(-abs(_b[placebo_disabled]/_se[placebo_disabled]))
    local model_num = `model_num' + 1
}

// 步骤4：输出安慰剂检验结果表
esttab robust3_model_1 robust3_model_2 robust3_model_3 using "稳健性检验3_安慰剂检验.rtf", replace ///
    title("表X3 稳健性检验：安慰剂检验（虚构残疾学生班级）") ///
    b(3) se(3)  ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("样本量" "调整后R²")) ///
    varlabels(placebo_disabled "虚构的班级有残疾学生" _cons "常数项") ///
    mlabels("亲子互动频率" "亲子关系质量" "父母投入感知") ///
    addnotes("注：安慰剂变量通过按班级随机分配0/1生成（种子=12345），若系数无显著效应，说明基线结论排除随机干扰")