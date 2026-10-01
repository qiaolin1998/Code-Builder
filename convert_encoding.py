
import codecs

input_file = r'f:\华为家庭存储\Project\Code Builder\Step7\SCL Source\FB2802_TwoShift_Yield.scl'
output_file = r'f:\华为家庭存储\Project\Code Builder\Step7\SCL Source\FB2802_TwoShift_Yield_gbk.scl'

with open(input_file, 'r', encoding='utf-8') as f:
    content = f.read()

with open(output_file, 'w', encoding='gb2312') as f:
    f.write(content)

print(f'文件已成功转换为GB2312编码并保存为: {output_file}')

