import csv
import re
from dns import resolver
import socket
import smtplib
from typing import Dict, Any
import logging
import time
import pandas as pd
from threading import Lock
import sys
from datetime import datetime
import concurrent.futures

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

class RateLimiter:
    def __init__(self):
        self.last_query_time = {}
        self.provider_last_query = {}
        self.global_last_query = 0
        self.lock = Lock()
        
        # 配置参数
        self.min_domain_interval = 0.3    # 单个域名最小间隔(秒)
        self.min_provider_interval = 0.2  # 单个服务商最小间隔(秒)
        self.min_global_interval = 0.1    # 全局最小间隔(秒)
        
        # 更新的邮件服务商域名映射
        self.provider_domains = {
            # Google
            'gmail.com': 'google',
            'googlemail.com': 'google',
            
            # Microsoft
            'outlook.com': 'microsoft',
            'hotmail.com': 'microsoft',
            'live.com': 'microsoft',
            'msn.com': 'microsoft',
            
            # Yahoo
            'yahoo.com': 'yahoo',
            'yahoo.co.jp': 'yahoo',
            'yahoomail.com': 'yahoo',
            
            # Apple
            'icloud.com': 'apple',
            'me.com': 'apple',
            'mac.com': 'apple',
            
            # 腾讯
            'qq.com': 'tencent',
            'foxmail.com': 'tencent',
            
            # 网易
            '163.com': 'netease',
            '126.com': 'netease',
            'yeah.net': 'netease',
            
            # 新浪
            'sina.com': 'sina',
            'sina.cn': 'sina',
            'sina.com.cn': 'sina',
            
            # 搜狐
            'sohu.com': 'sohu',
            'sohu.net': 'sohu',
            
            # ProtonMail
            'protonmail.com': 'proton',
            'protonmail.ch': 'proton',
            'pm.me': 'proton',
            
            # 阿里
            'aliyun.com': 'alibaba',
            'alimail.com': 'alibaba',
            
            # 其他主要中国邮箱服务商
            '139.com': 'china_mobile',    # 中国移动
            'wo.cn': 'china_unicom',      # 中国联通
            '21cn.com': '21cn',
            'tom.com': 'tom',
            
            # 其他国际邮箱服务商
            'zoho.com': 'zoho',
            'mail.com': 'mail_com',
            'yandex.com': 'yandex',
            'yandex.ru': 'yandex'
        }
        
        # 服务商速率限制配置（可以针对不同服务商设置不同的限制）
        self.provider_limits = {
            'google': 0.3,      # Google 较严格
            'microsoft': 0.3,   # Microsoft 较严格
            'yahoo': 0.3,       # Yahoo 较严格
            'tencent': 0.2,     # 腾讯相对宽松
            'netease': 0.2,     # 网易相对宽松
            'default': 0.3      # 默认限制
        }
    
    def get_provider_limit(self, provider: str) -> float:
        """获取服务商的速率限制"""
        return self.provider_limits.get(provider, self.provider_limits['default'])
    
    def wait(self, domain: str):
        """实施速率限制"""
        with self.lock:
            current_time = time.time()
            provider = self.get_provider(domain)
            provider_limit = self.get_provider_limit(provider)
            
            # 检查域名限制
            if domain in self.last_query_time:
                domain_wait = self.min_domain_interval - (current_time - self.last_query_time[domain])
                if domain_wait > 0:
                    time.sleep(domain_wait)
            
            # 检查服务商限制
            if provider in self.provider_last_query:
                provider_wait = provider_limit - (current_time - self.provider_last_query[provider])
                if provider_wait > 0:
                    time.sleep(provider_wait)
            
            # 检查全局限制
            global_wait = self.min_global_interval - (current_time - self.global_last_query)
            if global_wait > 0:
                time.sleep(global_wait)
            
            # 更新时间戳
            current_time = time.time()
            self.last_query_time[domain] = current_time
            self.provider_last_query[provider] = current_time
            self.global_last_query = current_time

    def get_provider(self, domain: str) -> str:
        """获取域名对应的服务商"""
        return self.provider_domains.get(domain.lower(), domain.lower())

class EmailValidator:
    def __init__(self, timeout: int = 10):
        self.timeout = timeout
        self.basic_regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        
        # DNS解析器配置
        self.resolver = resolver.Resolver()
        self.resolver.timeout = timeout
        self.resolver.lifetime = timeout
        self.resolver.nameservers = [
            '8.8.8.8',    # Google DNS
            '1.1.1.1',    # Cloudflare DNS
        ]
        
        self.rate_limiter = RateLimiter()
    
    def verify_dns(self, domain: str) -> tuple:
        """DNS验证"""
        try:
            self.rate_limiter.wait(domain)
            mx_records = self.resolver.resolve(domain, 'MX')
            return True, [str(r.exchange).rstrip('.') for r in mx_records]
        except Exception as e:
            return False, []

    def verify_smtp(self, mx_server: str, domain: str) -> tuple:
        """SMTP验证"""
        try:
            self.rate_limiter.wait(domain)
            with smtplib.SMTP(timeout=self.timeout) as smtp:
                smtp.connect(mx_server, port=25)
                return True, ''
        except Exception as e:
            return False, str(e)

    def validate_email(self, email: str) -> Dict[str, Any]:
        """验证单个邮箱"""
        result = {
            'email': email,
            'is_valid': False,
            'has_mx': False,
            'smtp_valid': False,
            'mx_records': [],
            'error_message': '',
            'time_taken': 0
        }
        
        start_time = time.time()
        
        try:
            # 基本检查
            if not email or pd.isna(email):
                result['error_message'] = '邮箱为空'
                return result
            
            email = str(email).strip().lower()
            
            # 格式验证
            if not re.match(self.basic_regex, email):
                result['error_message'] = '格式无效'
                return result
            
            # DNS验证
            domain = email.split('@')[1]
            has_mx, mx_records = self.verify_dns(domain)
            
            result['mx_records'] = mx_records
            result['has_mx'] = has_mx
            
            if not has_mx:
                result['error_message'] = '域名MX记录不存在'
                return result
            
            # SMTP验证
            smtp_valid, smtp_error = self.verify_smtp(mx_records[0], domain)
            result['smtp_valid'] = smtp_valid
            
            if not smtp_valid:
                result['error_message'] = smtp_error
                return result
            
            result['is_valid'] = True
            
        except Exception as e:
            result['error_message'] = f'验证错误: {str(e)}'
        finally:
            result['time_taken'] = round((time.time() - start_time) * 1000)
        
        return result

def process_file(input_file: str, max_workers: int = 5):
    """处理CSV文件"""
    start_time = time.time()
    logging.info(f"开始处理文件: {input_file}")
    
    try:
        # 读取CSV文件
        df = pd.read_csv(input_file)
        total_emails = len(df)
        processed = 0
        valid_count = 0
        
        logging.info(f"总共需要处理 {total_emails} 个邮箱\n")
        
        # 创建或更新结果列
        df['valid_format'] = False
        df['has_mx'] = False
        df['smtp_valid'] = False
        df['mx_servers'] = ''
        df['error_message'] = ''
        df['validation_time_ms'] = 0
        
        # 进度显示格式
        format_str = "{:<30} {:<12} {:<8} {:<8} {:<8} {:<20}"
        
        # 打印表头
        logging.info(format_str.format(
            '邮箱', '结果', 'DNS', 'SMTP', '耗时', '错误信息'
        ))
        logging.info("-" * 80)
        
        # 初始化验证器
        validator = EmailValidator()
        
        # 处理每个邮箱
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {
                executor.submit(validator.validate_email, email): idx
                for idx, email in enumerate(df['email'])
            }
            
            for future in concurrent.futures.as_completed(futures):
                idx = futures[future]
                try:
                    result = future.result()
                    
                    # 更新DataFrame
                    df.at[idx, 'valid_format'] = True
                    df.at[idx, 'has_mx'] = result['has_mx']
                    df.at[idx, 'smtp_valid'] = result['smtp_valid']
                    df.at[idx, 'mx_servers'] = ','.join(result['mx_records'])
                    df.at[idx, 'error_message'] = result['error_message']
                    df.at[idx, 'validation_time_ms'] = result['time_taken']
                    
                    processed += 1
                    if result['is_valid']:
                        valid_count += 1
                    
                    # 显示验证结果
                    logging.info(format_str.format(
                        result['email'][:30],
                        '✓ 有效' if result['is_valid'] else '✗ 无效',
                        '✓' if result['has_mx'] else '✗',
                        '✓' if result['smtp_valid'] else '✗',
                        str(result['time_taken']),
                        result['error_message'][:20]
                    ))
                    
                    # 每处理100个邮箱保存一次
                    if processed % 100 == 0:
                        df.to_csv(input_file, index=False)
                        logging.info(f"\n已处理: {processed}/{total_emails} ({processed/total_emails*100:.1f}%)\n")
                    
                except Exception as e:
                    logging.error(f"处理错误: {str(e)}")
        
        # 保存最终结果
        df.to_csv(input_file, index=False)
        
        # 打印统计信息
        total_time = time.time() - start_time
        logging.info(f"""
验证完成:
- 总邮箱数: {total_emails}
- 有效邮箱数: {valid_count}
- 无效邮箱数: {total_emails - valid_count}
- 有效率: {(valid_count/total_emails*100):.1f}%
- 总耗时: {total_time:.1f}秒
- 平均速度: {(total_time/total_emails*1000):.1f}毫秒/封
- 结果已保存到: {input_file}
        """)
        
    except Exception as e:
        logging.error(f"处理过程发生错误: {str(e)}")
        raise

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("使用方法: python validator.py input.csv")
        sys.exit(1)
    
    input_file = sys.argv[1]
    process_file(input_file)