// 加载第一部分保存的中间数据（非残疾学生与核心残疾变量）
clear all
set more off
cd "D:\导师\寒假\大作业\大作业\数据"
use "七年级非残疾学生数据_核心变量.dta", clear

// 被解释变量：亲子关系（3个维度）
// 维度1：亲子互动频率（基于共同活动频率变量，标准化为0-100分，分数越高互动越频繁）
local interaction_vars "b2801 b2802 b2803 b2804 b2805 b2806"  // 吃饭/读书/看电视/运动/参观/看电影
egen interaction_freq_raw = rowmean(`interaction_vars')  // 计算原始均值（1-6分制）
// 标准化（加边界限制避免超出0-100分）
egen interaction_freq = std(interaction_freq_raw)
replace interaction_freq = (interaction_freq + 3) * 20  // 转为0-100分制
replace interaction_freq = 0 if interaction_freq < 0  // 强制最小值为0
replace interaction_freq = 100 if interaction_freq > 100  // 强制最大值为100
label var interaction_freq "亲子互动频率（0-100分）"

// 维度2：亲子关系质量（基于亲子情感连接变量，标准化为0-100分，分数越高质量越好）
local quality_vars "b2501 b2502"  // 和妈妈的关系/和爸爸的关系（1-3分制）
egen quality_raw = rowmean(`quality_vars')
egen relationship_quality = std(quality_raw)
replace relationship_quality = (relationship_quality + 3) * 20
replace relationship_quality = 0 if relationship_quality < 0  // 边界限制
replace relationship_quality = 100 if relationship_quality > 100
label var relationship_quality "亲子关系质量（0-100分）"

// 维度3：父母投入感知（基于学生对父母付出的评价，标准化为0-100分）
gen investment_raw = b29  // 觉得父母为你做的多吗（1-5分制）
egen parental_investment = std(investment_raw)
replace parental_investment = (parental_investment + 3) * 20
replace parental_investment = 0 if parental_investment < 0  // 边界限制
replace parental_investment = 100 if parental_investment > 100
label var parental_investment "父母投入感知（0-100分）"


// 构建控制变量
// 学生层面控制变量
gen gender = (a01 == 1) if !missing(a01)  // 性别：1=男，0=女
label var gender "性别（1=男，0=女）"

gen age = 2013 - a02a if !missing(a02a)  // 年龄（2013为CEPS基线调查年份）
label var age "年龄"

gen minority = (a03 != 1) if !missing(a03)  // 少数民族：1=是，0=否（1=汉族）
label var minority "少数民族（1=是，0=否）"

// 家庭层面控制变量
gen only_child = (b01 == 1) if !missing(b01)  // 独生子女：1=是，0=否
label var only_child "独生子女（1=是，0=否）"

gen mother_edu = b06 if !missing(b06)  // 母亲受教育年限
replace mother_edu = 0 if mother_edu < 0  // 剔除负向异常值
label var mother_edu "母亲受教育年限"

gen father_edu = b07 if !missing(b07)  // 父亲受教育年限
replace father_edu = 0 if father_edu < 0  // 剔除负向异常值
label var father_edu "父亲受教育年限"

gen family_eco = b09 if !missing(b09)  // 家庭经济状况（1=非常困难，5=非常好）
replace family_eco = . if family_eco < 1 | family_eco > 5  // 剔除超出1-5分的异常值
label var family_eco "家庭经济状况（1-5分）"

gen rural = (a06 == 1) if !missing(a06)  // 农村户口：1=是，0=否
label var rural "农村户口（1=是，0=否）"

// 班级层面控制变量（第一部分构建的class_size）
label var class_size "班级规模（人数）"

// 变量清洗
// 缺失值处理：核心变量缺失率<10%，用班级均值填充；>10%直接剔除
local core_vars "interaction_freq relationship_quality parental_investment gender age only_child mother_edu father_edu family_eco rural class_size"
foreach var of local core_vars {
    bysort schids clsids: egen temp_mean = mean(`var')
    replace `var' = temp_mean if missing(`var')
    drop temp_mean
}

// 异常值处理：对3个核心连续变量做上下1%缩尾处理
local continuous_vars "interaction_freq relationship_quality parental_investment"
foreach var of local continuous_vars {
    // 计算变量的1%分位数和99%分位数
    xtile pct_group = `var', nq(100)  // 将变量分为100个百分位
    sum `var' if pct_group == 1, meanonly  // 提取1%分位数
    local lower = r(mean)
    sum `var' if pct_group == 99, meanonly  // 提取99%分位数
	display "`var' 1%分位数：" %5.3f `lower' ", 99%分位数：" %5.3f `upper'
    local upper = r(mean)
    
    // 替换极端值
    replace `var' = `lower' if `var' < `lower'
    replace `var' = `upper' if `var' > `upper'
    
    // 删除临时分组变量
    drop pct_group
}

// 验证异常值处理结果（确保无极端值，分布合理）
sum `continuous_vars', detail

// 最终样本筛选
drop if missing(interaction_freq, relationship_quality, parental_investment, gender, age, only_child, mother_edu, father_edu, family_eco, rural, class_size)
count  // 记录最终有效样本量

// 保存处理后的数据
save "七年级非残疾学生数据_完整变量.dta", replace

// 初步描述性统计
// 对比两组班级的"亲子互动频率"均值
tab has_disabled, sum(interaction_freq) nofreq  
// 对比两组班级的"亲子关系质量"均值
tab has_disabled, sum(relationship_quality) nofreq 
// 对比两组班级的"父母投入感知"均值
tab has_disabled, sum(parental_investment) nofreq 