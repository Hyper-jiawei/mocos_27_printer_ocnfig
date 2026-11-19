-- OneClickPrinterConfig.applescript
-- macOS 一键配置 SHARP MX-C3051R 网络打印机
-- 双击运行后弹出 IPv4 输入框，输入地址后自动完成全部配置
-- 作者: hyper-jiawei

-- ============ 可配置项 ============
set printerName to "MX-C3051R"
set printerDisplayName to "SHARP MX-C3051R"
set ppdPath to "/Library/Printers/PPDs/Contents/Resources/SHARP MX-C3051R.PPD.gz"
set printerLocation to "网络打印机"
set defaultIP to "172.16.163.246"

-- ============ 主流程 ============
tell application "System Events"
	activate
end tell

-- 1. 弹出 IPv4 输入框
set userInput to display dialog "请输入 Sharp 打印机（MX-C3051R）的 IPv4 地址：" & return & return & "可在打印机面板的「网络设置」中查看。" default answer defaultIP buttons {"取消", "开始配置"} default button "开始配置" with title "一键配置打印机" with icon note

if button returned of userInput is "取消" then return
set ipAddress to text returned of userInput

-- 去除首尾空格
set ipAddress to my trim(ipAddress)

-- 2. 校验 IPv4 格式
if not (my isValidIPv4(ipAddress)) then
	display dialog "IPv4 地址格式不正确：" & return & ipAddress & return & return & "请确认后重新运行。" buttons {"好"} default button "好" with title "输入有误" with icon stop
	return
end if

-- 3. 检查驱动是否存在
set ppdExists to do shell script "test -f " & quoted form of ppdPath & " && echo yes || echo no"
if ppdExists is "no" then
	display dialog "未找到 SHARP MX-C3051R 驱动程序。" & return & return & "请先安装 Sharp 官方 macOS 驱动后再运行本程序。" buttons {"好"} default button "好" with title "缺少驱动" with icon caution
	return
end if

-- 4. 检测打印机连通性（可选提示，不阻断）
set isReachable to do shell script "ping -c 1 -W 1500 " & quoted form of ipAddress & " >/dev/null 2>&1 && echo yes || echo no"
if isReachable is "no" then
	set cont to display dialog "无法 ping 通 " & ipAddress & return & return & "请确认：① 打印机已开机并联网  ② 电脑与打印机在同一网络（如需 VPN 请先连接）。" & return & return & "是否仍要继续配置？" buttons {"取消", "继续"} default button "继续" with title "网络提示" with icon caution
	if button returned of cont is "取消" then return
end if

-- 5. 显示进度
set progressDialog to display dialog "正在配置打印机，请稍候…" & return & return & "地址：" & ipAddress buttons {"取消"} default button "取消" with title "配置中" with icon note giving up after 60

-- 6. 执行配置命令
try
	set deviceURI to "socket://" & ipAddress & ":9100"
	set locationText to printerLocation & " " & ipAddress
	
	-- 清理同名旧配置（若存在）
	do shell script "/usr/sbin/lpadmin -x " & quoted form of printerName & " 2>/dev/null || true"
	
	-- 添加打印机（使用 socket:// RAW 9100 端口 + 原厂 PPD）
	do shell script "/usr/sbin/lpadmin -p " & quoted form of printerName & " -E -v " & quoted form of deviceURI & " -P " & quoted form of ppdPath & " -D " & quoted form of printerDisplayName & " -L " & quoted form of locationText
	
	-- 设为默认打印机
	do shell script "/usr/sbin/lpadmin -d " & quoted form of printerName
	
	-- 启用队列并接受任务
	do shell script "/usr/sbin/cupsenable " & quoted form of printerName
	do shell script "/usr/sbin/cupsaccept " & quoted form of printerName
	
	-- 验证
	set finalState to do shell script "/usr/bin/lpstat -p " & quoted form of printerName & " 2>&1"
	set finalURI to do shell script "/usr/bin/lpstat -v " & quoted form of printerName & " 2>&1"
	
	-- 成功提示
	display dialog "✓ 打印机配置成功！" & return & return & "名称：" & printerName & return & "地址：" & ipAddress & return & "端口：9100 (RAW)" & return & "默认打印机：是" & return & return & "现在可以在浏览器中打印了。" buttons {"好"} default button "好" with title "配置完成" with icon note
	
on error errMsg number errNum
	display dialog "配置失败，错误信息：" & return & return & errMsg & return & return & "错误代码：" & errNum buttons {"好"} default button "好" with title "配置失败" with icon stop
end try

-- ============ 工具函数 ============

-- 去除首尾空白字符
on trim(theText)
	set theText to my replaceText(theText, "  ", " ")
	set trimmed to do shell script "echo " & quoted form of theText & " | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'"
	return trimmed
end trim

-- 简单字符串替换
on replaceText(theText, oldStr, newStr)
	set AppleScript's text item delimiters to oldStr
	set textItems to text items of theText
	set AppleScript's text item delimiters to newStr
	set theText to textItems as text
	set AppleScript's text item delimiters to ""
	return theText
end replaceText

-- 校验 IPv4 地址格式（四段，每段 0-255）
on isValidIPv4(ip)
	setAppleScriptDelimiters to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "."
	set parts to text items of ip
	set AppleScript's text item delimiters to setAppleScriptDelimiters
	if (count of parts) is not 4 then return false
	repeat with p in parts
		set pStr to p as text
		if pStr is "" then return false
		-- 只允许数字：逐字符检查
		repeat with c in pStr
			set cStr to c as text
			if cStr is not in "0123456789" then return false
		end repeat
		set pNum to (pStr as integer)
		if pNum < 0 or pNum > 255 then return false
	end repeat
	return true
end isValidIPv4
