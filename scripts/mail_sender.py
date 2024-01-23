import argparse
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import pandas as pd

parser = argparse.ArgumentParser(description="mail sender")
parser.add_argument('--job_name', type=str, help='job name')
parser.add_argument('--job_url', type=str, help='job url')
parser.add_argument('--job_status', type=str, default='SUCCESS', choices=["SUCCESS", "FAILURE"], help='job status')
parser.add_argument('--result_file', type=str, help='path to result files')
args = parser.parse_args()

# sender & receivers
mail_sender = "xpu_backend_for_triton@intel.com"
mail_receivers = "yudong.si@intel.com"  # dse.ai.compilers.triton@intel.com

# create message container
msg = MIMEMultipart()

# setting
msg['Subject'] = f"[{args.job_status}] Intel XPU Backend for Triton: {args.job_name}"
msg['From'] = mail_sender
msg['To'] = mail_receivers


def summary2html(res_file):
    res = " "
    try:
        # E2E excel performance report
        if os.path.splitext(res_file)[1] == '.xlsx':
            content = pd.read_excel(res_file, sheet_name=["Summary"])['Summary']
            res = pd.DataFrame(content).to_html(classes="table", index=False)
        else:
            with open(res_file, mode="r") as file:
                for line in file:
                    res += f'''<p style="text-align:center"><strong>{line.strip()}</strong></p>\n'''
    except:
        pass
    return res


# body
head = f"""
<html>
<body>
    <head><title><strong>Job Status:</strong> {args.job_status}</title></head>
    <p style="text-align:center"><strong>Job Name:</strong> {args.job_name}</p>
    <p style="text-align:center"><strong>Build URL:</strong> <a href={args.job_url}> {args.job_url} </a></p>
    <p style="text-align:center"><strong>Summary:</strong></p>
""" + summary2html(args.result_file)
tail = """
</body>
</html>
"""
msg.attach(MIMEText(head + tail, 'html'))

# attachment
if args.result_file:
    with open(args.result_file, 'rb') as attachment:
        part = MIMEBase('application', 'octet-stream')
        part.set_payload(attachment.read())
        encoders.encode_base64(part)
        part.add_header('Content-Disposition', f"attachment; filename= {args.result_file}")
        msg.attach(part)

# sent
s = smtplib.SMTP('smtp.intel.com', 25)
s.send_message(msg)
s.quit()
