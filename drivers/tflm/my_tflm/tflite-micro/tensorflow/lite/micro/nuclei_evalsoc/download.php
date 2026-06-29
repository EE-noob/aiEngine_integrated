

  <!doctype html>
<html lang="ch">

	<head>
		<title>DOCS & TOOLS_Nuclei-Best RISC-V Processor IP</title>
		<meta charset="utf-8" />
		<meta http-equiv="Expires" content="-1" />
		<meta http-equiv="pragram" content="no-cache" />
		<meta name="apple-touch-fullscreen" content="YES" />
		<meta name="format-detection" content="telephone=no" />
		<meta name="apple-mobile-web-app-capable" content="yes" />
		<meta name="apple-mobile-web-app-status-bar-style" content="black" />
		<meta name="viewport" content="width=device-width, initial-scale=0.6, minimum-scale=0.6, maximum-scale=1.0, user-scalable=no">
		<meta name="description" content="芯来集成开发环境 Nuclei Studio,基于Eclipse IDE框架，配合易懂的用户手册，用户可以快速上手" />
		<meta name="keywords" content="RISC-V GNU,Nuclei OpenOCD,Nuclei Studio,芯来,芯来科技,芯来科技官网,芯来科技有限公司,芯来处理器,RISC-V IP" />
		<meta name="author" content="DOCS & TOOLS_Nuclei-Best RISC-V Processor IPNuclei System Technology" />
		<meta name="copyright" content="DOCS & TOOLS_Nuclei-Best RISC-V Processor IPNuclei System Technology" />
        
        <script type="text/javascript" src="/theme/js/jquery.min.js?_t=202508201100"></script>
        <!-- 最新的 Bootstrap 核心 css 文件 -->
        <link rel="stylesheet" href="/theme/bootstrap/css/bootstrap.min.css?_t=202508201100">
        <!-- 最新的 Bootstrap 核心 JavaScript 文件 -->
        <script src="/theme/bootstrap/js/bootstrap.min.js?_t=202508201100"></script>
        
		<link rel="stylesheet" type="text/css" href="/theme/css/common.css?_t=202508201100" />
		<link rel="stylesheet" type="text/css" href="/theme/css/index.css?_t=202508201100" />
                <link rel="stylesheet" type="text/css" href="/theme/css/zoom.css?_t=202508201100" />
        		<link rel="stylesheet" type="text/css" href="/theme/css/fullpage.css?_t=202508201100" />
        <link rel="stylesheet" type="text/css" href="/theme/css/font-awesome-4.7.0/css/font-awesome.min.css?_t=202508201100">  
<script>
var _hmt = _hmt || [];
(function() {
  var hm = document.createElement("script");
  hm.src = "https://hm.baidu.com/hm.js?5b02d8320959e62ab2108e1728447fa1";
  var s = document.getElementsByTagName("script")[0]; 
  s.parentNode.insertBefore(hm, s);
})();

$('div').fadeIn(500, function() {
    // 动画完成后的操作
    console.log('元素已完全显示');
});
</script>
	</head>
	<body>
		<header class="header">
			<div class="wrap">
				<div class="fixNavBtn" id="fixNavBtn">
				    <span class="bar"></span>
				    <span class="bar"></span>
				    <span class="bar"></span>
				</div>
				<div class="fixNavBtn" style="width: unset;margin-top: 5px;">
				    <ul style="display: inline-block;vertical-align: middle;">
                        <a href="?en=1" class="" style="border: 1px solid #fff;color: #fff;border-radius: 5px; padding: 5px 10px;font-size: 20px;">中文</a>
                    </ul>
				</div>
                <div class="h-logo"><object id="logo" type="image/svg+xml" data="/theme/bg/logo.svg" width="129" height="40"></object></div>
				<div class="h-nav">
					<ul class="menu clearfix lifl">
						<li><a class="one " href="/index.php">Home</a></li>
						<li class="fmenu">
                            <p class="one " href="#">Products</p>
                            <div class="ts-dropdown dropdown-list pull-right two">
                                <ul class="ts-dropdown-list">
                                    <li><a href="/product.php">RISC-V CPU IP</a></li>
									<li><a href="/socip.php">Nuclei SoC IP</a></li>
									<li><a href="/subsystem.php">Custom SoC Subsystem</a></li>
									<li><a href="/solution.php">Subsystem Solution</a>
                                        <div class="ts-dropdown three" style="position: absolute;top: 100%;left: 100%;transform: translateY(-25%);">
                                            <ul class="ts-dropdown-list">
												<li><a href="/hsm.php">HSM Subsystem</a></li>
												<li><a href="/automotive.php">Automotive Subsystem</a></li>
												<li><a href="/ai.php">AI Subsystem</a></li>
												<li><a href="/wifi.php">WiFi Subsystem</a></li>
                                            </ul>
                                        </div>
									</li>
									
                                </ul>
                            </div>
                        
                        </li>
                        <li class="fmenu">
                            <p class="one " href="#">News</p>
                            <div class="ts-dropdown dropdown-list pull-right two">
                                <ul class="ts-dropdown-list">
                                    <li><a href="/news.php">Company News</a></li>
                                    <li><a href="/productnews.php">Product News</a></li>
                                </ul>
                            </div>
                        </li>
                        <li class="fmenu">
                            <p class="one  on" href="#">Resources</p>
                            <div class="ts-dropdown dropdown-list pull-right two">
                                <ul class="ts-dropdown-list">
                                    <li>
                                        <a>Development Boards</a>
                                        <div class="ts-dropdown three" style="position: absolute;top:150%;left: 100%;transform: translateY(-100%);">
                                            <ul class="ts-dropdown-list">
                                                <li><a href="/developboard.php">Chip Development Board</a></li>
                                                <li><a href="/developboard.php#ddr200t">FPGA Development Board</a></li>
                                                <li><a href="/developboard.php#debuggerkit">Debugger</a></li>
                                                
                                            </ul>
                                        </div>
                                    </li>
                                    <li>
										<a>Docs & Tools</a>
										<div class="ts-dropdown three" style="position: absolute;top:150%;left: 100%;transform: translateY(-100%);">
										    <ul class="ts-dropdown-list">
										        <li><a href="/download.php">Tools Download</a></li>
										        <li><a href="https://doc.nucleisys.com/"  target="_blank">Docs Center</a></li>
										    </ul>
										</div>
									</li>
                                </ul>
                            </div>
                        </li>
						<li class="fmenu">
                            <p class="one " href="#">About</p>
                            <div class="ts-dropdown dropdown-list pull-right two">
                                <ul class="ts-dropdown-list">
                                    <li><a href="/about.php">Company</a></li>
                                    <li><a href="/join.php">Join US</a></li>
                                    <li><a href="/contact.php">Contact</a></li>
                                </ul>
                            </div>
                        </li>
						<li class="fmenu"><a class="one " target="_blank" href="https://www.rvmcu.com">RISC-V MCU</a></li>
					</ul>
					
                    <ul class="menu clearfix" id="common-hd-nav">
                    	<li class="common-hd-user-nav">
                            <span class="">User Center</span>
                            <div class="common-hd-user-service-menu">
                                <div class="common-hd-drop-down" style="display: none;">
                                                              <a href="http://user.nucleisys.com/login_page.php" target="_blank" class="login">Login</a> <a>|</a>
                               <a href="http://user.nucleisys.com/signup_page.php" target="_blank" class="login">Register</a>
                               
                                                               </div>
                            </div>
                        </li>
                    </ul>
                    <script>
                            $('#common-hd-nav').find('li').bind({
                                mouseenter: function(){
                                    $(this).children('a').addClass('common-hd-arrow-up').end().find('.common-hd-drop-down').show();
                                },
                                mouseleave: function(){
                                    $(this).children('a').removeClass('common-hd-arrow-up').end().find('.common-hd-drop-down').hide();
                                }
                            });
                            </script>
					
                    <ul class="menu clearfix">
                        <li class="common-hd-user-nav">
                                <a href="?en=1" style="border: 2px solid #fff;padding:5px; border-radius: 5px;color: #fff;">中文</a>
                        </li>
                    </ul>
				</div>
                
                <script>
                    document.getElementById('logo').onload = function () {
                        document.getElementById("logo").contentDocument.getElementById("layer101").setAttribute("style", "fill:#ffffff");
                    }
                </script>
			</div>
		</header>
		<div class="fixNav" style="display: none;">
            
            <ul class="list">
            	<li class="item"><a  href="/index.php">Home</a></li>
            	<li class="item">
                    <a  href="#">Products</a>
                    <div class="ts-dropdown dropdown-list">
                        <ul class="ts-dropdown-list">
                            <li><a href="/product.php">RISC-V CPU IP</a></li>
							<li><a href="/socip.php">Nuclei SoC IP</a></li>
							<li><a href="/subsystem.php">Custom SoC Subsystem</a></li>
                            <li><a href="/subsystem.php">Custom SoC Subsystem</a></li>
							<li><a>Subsystem Solution</a>
							    <div class="ts-dropdown three">
							        <ul class="ts-dropdown-list">
										<li><a href="/hsm.php">HSM Subsystem</a></li>
										<li><a href="/automotive.php">Automotive Subsystem</a></li>
										<li><a href="/ai.php">AI Subsystem</a></li>
										<li><a href="/wifi.php">WiFi Subsystem</a></li>
							        </ul>
							    </div>
							</li>
							
                        </ul>
                    </div>
                
                </li>
                <li class="item">
                    <a  href="#">News</a>
                    <div class="ts-dropdown dropdown-list">
                        <ul class="ts-dropdown-list">
                            <li><a href="/news.php">Company News</a></li>
                            <li><a href="/productnews.php">Product News</a></li>
                        </ul>
                    </div>
                </li>
                <li class="item">
                    <a  class="on" href="#">Resources</a>
                    <div class="ts-dropdown dropdown-list">
						<ul class="ts-dropdown-list">
						    <li>
						        <a>Development Boards</a>
						        <div class="ts-dropdown three">
						            <ul class="ts-dropdown-list">
						                <li><a href="/developboard.php">Chip Development Board</a></li>
						                <li><a href="/developboard.php#ddr200t">FPGA Development Board</a></li>
						                <li><a href="/developboard.php#debuggerkit">Debugger</a></li>
						            </ul>
						        </div>
						    </li>
						    <li>
								<a>Docs & Tools</a>
								<div class="ts-dropdown three">
								    <ul class="ts-dropdown-list">
								        <li><a href="/download.php">Tools Download</a></li>
								        <li><a href="https://doc.nucleisys.com/"  target="_blank">Docs Center</a></li>
								    </ul>
								</div>
							</li>
						</ul>
                    </div>
                </li>
            	<li class="item">
                    <a  href="#">About</a>
                    <div class="ts-dropdown dropdown-list">
                        <ul class="ts-dropdown-list">
                            <li><a href="/about.php">Company</a></li>
                            <li><a href="/join.php">Join US</a></li>
                            <li><a href="/contact.php">Contact</a></li>
                        </ul>
                    </div>
                </li>
            	<li class="item"><a target="_blank" href="https://www.rvmcu.com">RISC-V MCU</a></li>
                <li class="item"><a  href="/campus.php">大学计划</a></li>
            </ul>
            
            

			<div class="bottom">
				                    <a href="http://user.nucleisys.com/login_page.php" class="entry f-login">Login</a>
                    <a href="http://user.nucleisys.com/signup_page.php" class="entry f-register">Register</a>
                    			</div>
            
            <script type="text/javascript">
             	$(function(){
             		$(".fixNav li").click(function(){
             			$(this).children(".ts-dropdown").show();
             		});
             	});
             </script>
			
		</div>
		<style>
            .section .info h3.title.slogan {
                letter-spacing: 0px;
                color: #ffffff;
                font-size: 72px;
            }
        </style>
				<div class="nbanner">
			<div class="img">
   

<img src="/upload/image/2019/04/1556631012-2200.jpg"/>

				<div class="info">
				<h3><p>Docs & Tools</p></h3>
					<h4>
						下载中心					</h4>
				</div>
 

			</div>
		</div>


		
		
		
<link rel="stylesheet" type="text/css" href="/theme/css/download.css?_t=202508201100" />

<div class="container mt-5 subsystem">
    <div class="col-md-12 col-12">
        <div class="title"><a href="#tools">
			    Nuclei Toolchain			</a></div>
    </div>
</div>

<div class="container"> 

    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-5 col-12 x-left">
            Nuclei Studio IDE                
            </div>
            <div class="col-md-7 col-12 bc1 x-right">
                <div class="entry">
                                    <div class="items">
                    
                    <!--- start  --> 
                                            <div class="item">
                            <div class="master">
                                <a href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202502-win64.zip" target="_blank" title="Windows 10/11">
                                    <span class="lspan"><img src="/theme/bg/download.png"></span> Windows 10/11                                </a>
                                
                                                                <div class="versionSelect"><span></span></div>
                                                                
                            </div>
                            
                                                        <ul id="versionList" class="versionList">
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202502-win64.zip">2025.02 (win10/11)</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202406-win64.zip">2024.06 (win10/11)</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202402_DEV-win64.zip">2024.02</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202212-win64.zip">2022.12</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202208-win64.zip">2022.08</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202204-win64.zip">2022.04</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202201-win64.zip">2022.01</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202102-win64.zip">2021.02</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202009-win64.zip">2020.09</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_201909.rar">2019.09</a></li>
                                                            </ul>   
                                                        
                        </div>
                    
                                                
                <!--- end  -->
                <!--- start  -->         
                        
                                    <div class="item">
                        <div class="master">
                            <a href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202502-lin64.tgz" target="_blank" title="Linux x86-64">
                                <span class="lspan"><img src="/theme/bg/download.png"></span> Linux x86-64                            </a>
                            
                                                        <div class="versionSelect"><span></span></div>
                                                        
                        </div>
                        
                                                <ul id="versionList" class="versionList">
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202502-lin64.tgz">2025.02</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202406-lin64.tgz">2024.06</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202212-lin64.tgz">2022.12</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202208-lin64.tgz">2022.08</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202204-lin64.tgz">2022.04</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202201-lin64.tgz">2022.01</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202102-lin64.tgz">2021.02</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/nucleistudio/NucleiStudio_IDE_202009-lin64.tgz">2020.09</a></li>
                                                    </ul>   
                                                
                    </div>
                
                                                
                            
                     <!--- end  -->
                     <!--- start  -->        
                            
                                            <div class="item">
                            <div class="master">
                                <a href="https://download.nucleisys.com/upload/files/doc/nucleistudio/NucleiStudio_User_Guide.202502.pdf" target="_blank" title="User Guide">
                                    <span class="lspan"><img src="/theme/bg/download.png"></span> User Guide                                </a>
                                
                                                                <div class="versionSelect"><span></span></div>
                                                                
                            </div>
                            
                                                        <ul id="versionList" class="versionList">
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/doc/nucleistudio/NucleiStudio_User_Guide.202502.pdf">2025.02</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/doc/nucleistudio/Nuclei_Studio_User_Guide.202406.pdf">2024.06</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/doc/nucleistudio/Nuclei_Studio_User_Guide.202402.pdf">2024.02</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/doc/nucleistudio/Nuclei_Studio_User_Guide.202212.pdf">2022.12</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/doc/nucleistudio/Nuclei_Studio_User_Guide.202208.pdf">2022.08</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/doc/nucleistudio/Nuclei_Studio_User_Guide.202204.pdf">2022.04</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/doc/nucleistudio/Nuclei_Studio_User_Guide.20221.pdf">2022.01</a></li>
                                                            </ul>   
                                                        
                        </div>
                    
                                                
                        
                <!--- end  -->
				 <!--- start  -->
				 					 <div class="item">
						 <div class="master">
							 <a href="https://doc.nucleisys.com/nuclei_studio_supply" target="_blank" title="Supply Documents">
								 <span class="lspan"><img src="/theme/bg/out.png"></span> Supply Documents							 </a>
							 
							 							 
						 </div>
						 
						 						 
					 </div>
				 
					 						 
					 <!--- end  -->    
					 
                <!--- start  --> 
                                    <div class="item">
                        <div class="master">
                            <a href="https://www.rvmcu.com/nucleistudio-faq.html" target="_blank" title="FAQ">
                                <span class="lspan"><img src="/theme/bg/out.png"></span> FAQ                            </a>
                            
                                                        
                        </div>
                        
                                                
                    </div>
                
                                            
                    <!--- end  -->    
                        
        
                    </div>
    
                                

                </div>
            </div>
        
        
        
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-5 col-12 x-left">
            Nuclei RISC-V Embedded Toolchain(Baremetal/RTOS + Newlibc)                
            </div>
            <div class="col-md-7 col-12 bc1 x-right">
                <div class="entry">
                                    <div class="items">
                    
                    <!--- start  --> 
                                            <div class="item">
                            <div class="master">
                                <a href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_win32_2025.02.zip" target="_blank" title="Windows">
                                    <span class="lspan"><img src="/theme/bg/download.png"></span> Windows                                </a>
                                
                                                                <div class="versionSelect"><span></span></div>
                                                                
                            </div>
                            
                                                        <ul id="versionList" class="versionList">
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_win32_2025.02.zip">2025.02</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_win32_2024.06.zip">2024.06</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_win32_nuclei-2024.zip">2024.02</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_win32_2022.12.zip">2022.12</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_win32_2022.08.zip">2022.08</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_win32_2022.04.zip">2022.04</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_win32_2022.01.zip">2022.01</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_win32_2020.08.zip">2020.08</a></li>
                                                            </ul>   
                                                        
                        </div>
                    
                                                
                <!--- end  -->
                <!--- start  -->         
                        
                                    <div class="item">
                        <div class="master">
                            <a href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_linux64_2025.02.tar.bz2" target="_blank" title="Centos/Ubuntu x86-64">
                                <span class="lspan"><img src="/theme/bg/download.png"></span> Centos/Ubuntu x86-64                            </a>
                            
                                                        <div class="versionSelect"><span></span></div>
                                                        
                        </div>
                        
                                                <ul id="versionList" class="versionList">
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_linux64_2025.02.tar.bz2">2025.02</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_linux64_2024.06.tar.bz2">2024.06</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_linux64_nuclei-2024.tar.bz2">2024.02</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_linux64_2022.12.tar.bz2">2022.12</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_linux64_2022.08.tar.bz2">2022.08</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_linux64_2022.04.tar.bz2">2022.04</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_linux64_2022.01.tar.bz2">2022.01</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/gcc/nuclei_riscv_newlibc_prebuilt_linux64_2020.08.tar.bz2">2020.08</a></li>
                                                    </ul>   
                                                
                    </div>
                
                                                
                            
                     <!--- end  -->
                     <!--- start  -->        
                            
                                            
                        
                <!--- end  -->
				 <!--- start  -->
				 					 <div class="item">
						 <div class="master">
							 <a href="https://doc.nucleisys.com/nuclei_tools/toolchain/index.html" target="_blank" title="Online Doc">
								 <span class="lspan"><img src="/theme/bg/out.png"></span> Online Doc							 </a>
							 
							 							 
						 </div>
						 
						 						 
					 </div>
				 
					 						 
					 <!--- end  -->    
					 
                <!--- start  --> 
                                        
                    <!--- end  -->    
                        
        
                    </div>
    
                                

                </div>
            </div>
        
        
        
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-5 col-12 x-left">
            Nuclei OpenOCD                
            </div>
            <div class="col-md-7 col-12 bc1 x-right">
                <div class="entry">
                                    <div class="items">
                    
                    <!--- start  --> 
                                            <div class="item">
                            <div class="master">
                                <a href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2025.02-win32-x32.zip" target="_blank" title="Windows">
                                    <span class="lspan"><img src="/theme/bg/download.png"></span> Windows                                </a>
                                
                                                                <div class="versionSelect"><span></span></div>
                                                                
                            </div>
                            
                                                        <ul id="versionList" class="versionList">
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2025.02-win32-x32.zip">2025.02</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2024.06-win32-x32.zip">2024.06</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2024.02.28-win32-x32.zip">2024.02</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2022.12-win32-x32.zip">2022.12</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2022.08-win32-x32.zip">2022.08</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2022.04-win32-x32.zip">2022.04</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2022.01-win32-x32.zip">2022.01</a></li>
                                                            </ul>   
                                                        
                        </div>
                    
                                                
                <!--- end  -->
                <!--- start  -->         
                        
                                    <div class="item">
                        <div class="master">
                            <a href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2025.02-linux-x64.tgz" target="_blank" title="Linux x86-64">
                                <span class="lspan"><img src="/theme/bg/download.png"></span> Linux x86-64                            </a>
                            
                                                        <div class="versionSelect"><span></span></div>
                                                        
                        </div>
                        
                                                <ul id="versionList" class="versionList">
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2025.02-linux-x64.tgz">2025.02</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2024.06-linux-x64.tgz">2024.06</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2024.02.28-linux-x64.tgz">2024.02</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2022.12-linux-x64.tgz">2022.12</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2022.08-linux-x64.tgz">2022.08</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2022.04-linux-x64.tgz">2022.04</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/openocd/nuclei-openocd-2022.01-linux-x64.tgz">2022.01</a></li>
                                                    </ul>   
                                                
                    </div>
                
                                                
                            
                     <!--- end  -->
                     <!--- start  -->        
                            
                                            
                        
                <!--- end  -->
				 <!--- start  -->
				 					 <div class="item">
						 <div class="master">
							 <a href="https://doc.nucleisys.com/nuclei_tools/openocd/index.html" target="_blank" title="Online Doc">
								 <span class="lspan"><img src="/theme/bg/out.png"></span> Online Doc							 </a>
							 
							 							 
						 </div>
						 
						 						 
					 </div>
				 
					 						 
					 <!--- end  -->    
					 
                <!--- start  --> 
                                        
                    <!--- end  -->    
                        
        
                    </div>
    
                                

                </div>
            </div>
        
        
        
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-5 col-12 x-left">
            Nuclei QEMU                
            </div>
            <div class="col-md-7 col-12 bc1 x-right">
                <div class="entry">
                                    <div class="items">
                    
                    <!--- start  --> 
                                            <div class="item">
                            <div class="master">
                                <a href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2025.02-win32-x64.zip" target="_blank" title="Windows">
                                    <span class="lspan"><img src="/theme/bg/download.png"></span> Windows                                </a>
                                
                                                                <div class="versionSelect"><span></span></div>
                                                                
                            </div>
                            
                                                        <ul id="versionList" class="versionList">
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2025.02-win32-x64.zip">2025.02</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2024.06-win32-x64.zip">2024.06</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2024.04.29-win32-x64.zip">2024.04.29</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2024.02.21-win32-x64.zip">2024.02</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2022.12-win32-x64.zip">2022.12</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2022.08-win32-x64.zip">2022.08</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2022.04-win32-x64.zip">2022.04</a></li>
                                                            </ul>   
                                                        
                        </div>
                    
                                                
                <!--- end  -->
                <!--- start  -->         
                        
                                    <div class="item">
                        <div class="master">
                            <a href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2025.02-linux-x64.tar.gz" target="_blank" title="Linux x86-64">
                                <span class="lspan"><img src="/theme/bg/download.png"></span> Linux x86-64                            </a>
                            
                                                        <div class="versionSelect"><span></span></div>
                                                        
                        </div>
                        
                                                <ul id="versionList" class="versionList">
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2025.02-linux-x64.tar.gz">2025.02</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2024.06-linux-x64.tar.gz">2024.06</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2024.04.29-linux-x64.tar.gz">2024.04.29</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2024.02.21-linux-x64.tar.gz">2024.02</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2022.12-linux-x64.tar.gz">2022.12</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2022.08-linux-x64.tar.gz">2022.08</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/qemu/nuclei-qemu-2022.04-linux-x64.tar.gz">2022.04</a></li>
                                                    </ul>   
                                                
                    </div>
                
                                                
                            
                     <!--- end  -->
                     <!--- start  -->        
                            
                                            
                        
                <!--- end  -->
				 <!--- start  -->
				 					 <div class="item">
						 <div class="master">
							 <a href="https://doc.nucleisys.com/nuclei_tools/qemu/index.html" target="_blank" title="Online Doc">
								 <span class="lspan"><img src="/theme/bg/out.png"></span> Online Doc							 </a>
							 
							 							 
						 </div>
						 
						 						 
					 </div>
				 
					 						 
					 <!--- end  -->    
					 
                <!--- start  --> 
                                        
                    <!--- end  -->    
                        
        
                    </div>
    
                                

                </div>
            </div>
        
        
        
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-5 col-12 x-left">
            Nuclei Near Cycle Model                
            </div>
            <div class="col-md-7 col-12 bc1 x-right">
                <div class="entry">
                                    <div class="items">
                    
                    <!--- start  --> 
                                            <div class="item">
                            <div class="master">
                                <a href="https://download.nucleisys.com/upload/files/toolchain/xlmodel/xlmodel-win32-2025.02.zip" target="_blank" title="Windows">
                                    <span class="lspan"><img src="/theme/bg/download.png"></span> Windows                                </a>
                                
                                                                
                            </div>
                            
                                                        
                        </div>
                    
                                                
                <!--- end  -->
                <!--- start  -->         
                        
                                    <div class="item">
                        <div class="master">
                            <a href="https://download.nucleisys.com/upload/files/toolchain/xlmodel/xlmodel-linux64-2025.02.tar.gz" target="_blank" title="Linux x86-64">
                                <span class="lspan"><img src="/theme/bg/download.png"></span> Linux x86-64                            </a>
                            
                                                        
                        </div>
                        
                                                
                    </div>
                
                                                
                            
                     <!--- end  -->
                     <!--- start  -->        
                            
                                            
                        
                <!--- end  -->
				 <!--- start  -->
				 					 <div class="item">
						 <div class="master">
							 <a href="https://doc.nucleisys.com/nuclei_tools/xlmodel/index.html" target="_blank" title="Online Doc">
								 <span class="lspan"><img src="/theme/bg/out.png"></span> Online Doc							 </a>
							 
							 							 
						 </div>
						 
						 						 
					 </div>
				 
					 						 
					 <!--- end  -->    
					 
                <!--- start  --> 
                                        
                    <!--- end  -->    
                        
        
                    </div>
    
                                

                </div>
            </div>
        
        
        
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-5 col-12 x-left">
            Windows Build Tools                
            </div>
            <div class="col-md-7 col-12 bc1 x-right">
                <div class="entry">
                                    <div class="items">
                    
                    <!--- start  --> 
                                            <div class="item">
                            <div class="master">
                                <a href="https://download.nucleisys.com/upload/files/toolchain/build-tools/win32-buildtools-1.2.zip" target="_blank" title="Windows">
                                    <span class="lspan"><img src="/theme/bg/download.png"></span> Windows                                </a>
                                
                                                                <div class="versionSelect"><span></span></div>
                                                                
                            </div>
                            
                                                        <ul id="versionList" class="versionList">
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/build-tools/win32-buildtools-1.2.zip">2024.02</a></li>
                                                                    <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/build-tools/build-tools_202002.zip">2020.02</a></li>
                                                            </ul>   
                                                        
                        </div>
                    
                                                
                <!--- end  -->
                <!--- start  -->         
                        
                                            
                            
                     <!--- end  -->
                     <!--- start  -->        
                            
                                            
                        
                <!--- end  -->
				 <!--- start  -->
				 						 
					 <!--- end  -->    
					 
                <!--- start  --> 
                                        
                    <!--- end  -->    
                        
        
                    </div>
    
                                

                </div>
            </div>
        
        
        
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-5 col-12 x-left">
            Nuclei RISC-V Linux Toolchain(OpenSBI/Uboot/Linux + Glibc)                
            </div>
            <div class="col-md-7 col-12 bc1 x-right">
                <div class="entry">
                                    <div class="items">
                    
                    <!--- start  --> 
                                            <div class="item">
                            <div class="master">
                                <a href="https://download.nucleisys.com/upload/files/toolchain/linuxgcc/nuclei_riscv_glibc_prebuilt_win32_2025.02.zip" target="_blank" title="Windows">
                                    <span class="lspan"><img src="/theme/bg/download.png"></span> Windows                                </a>
                                
                                                                
                            </div>
                            
                                                        
                        </div>
                    
                                                
                <!--- end  -->
                <!--- start  -->         
                        
                                    <div class="item">
                        <div class="master">
                            <a href="https://download.nucleisys.com/upload/files/toolchain/linuxgcc/nuclei_riscv_glibc_prebuilt_linux64_2025.02.tar.bz2" target="_blank" title="Centos/Ubuntu x86-64">
                                <span class="lspan"><img src="/theme/bg/download.png"></span> Centos/Ubuntu x86-64                            </a>
                            
                                                        <div class="versionSelect"><span></span></div>
                                                        
                        </div>
                        
                                                <ul id="versionList" class="versionList">
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/linuxgcc/nuclei_riscv_glibc_prebuilt_linux64_2025.02.tar.bz2">2025.02-gcc14</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/linuxgcc/nuclei_riscv_glibc_prebuilt_linux64_nuclei-2023.tar.bz2">2024.02-gcc13</a></li>
                                                            <li class="download"><a target="_blank" href="https://download.nucleisys.com/upload/files/toolchain/linuxgcc/nuclei_riscv_glibc_prebuilt_linux64_2022.04.tar.bz2">2022.04-gcc10</a></li>
                                                    </ul>   
                                                
                    </div>
                
                                                
                            
                     <!--- end  -->
                     <!--- start  -->        
                            
                                            
                        
                <!--- end  -->
				 <!--- start  -->
				 					 <div class="item">
						 <div class="master">
							 <a href="https://doc.nucleisys.com/nuclei_tools/toolchain/index.html" target="_blank" title="Online Doc">
								 <span class="lspan"><img src="/theme/bg/out.png"></span> Online Doc							 </a>
							 
							 							 
						 </div>
						 
						 						 
					 </div>
				 
					 						 
					 <!--- end  -->    
					 
                <!--- start  --> 
                                        
                    <!--- end  -->    
                        
        
                    </div>
    
                                

                </div>
            </div>
        
        
        
        </div>    
    </div>

</div>


<div class="container mt-5 subsystem" id="ipdocs">
    <div class="col-md-12 col-12">
        <div class="title"><a href="#ipdocs">IP Product Databook</a></div>
    </div>
</div>

<div class="container"> 

    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-6 col-12 x-left">Click <a href="https://user.nucleisys.com" target="_blank" >Nuclei User Center</a> to access IP product's complete documents.</div>
            <div class="col-md-6 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                                    
                        <!--- start  --> 
                        <div class="item">
                            <div class="master">
                                <a href="https://user.nucleisys.com" target="_blank" title="Nuclei User Center">
                                     <span class="lspan"><img src="/theme/bg/icons8-person.gif"></span> Nuclei User Center
                                </a>                              
                            </div>                                           
                        </div>
                        <!--- end  -->

                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
</div>


<div class="container mt-5 subsystem" id="nsp">
    <div class="col-md-12 col-12">
        <div class="title"><a href="#nsp">Nuclei Software Platform</a></div>
    </div>
</div>

<div class="container"> 


    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">Nuclei Open Source Software Organization</div>
            <div class="col-md-8 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Nuclei-Software/" target="_blank" title="Nuclei Open Source Software Organization">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/Nuclei-Software/" target="_blank" title="Nuclei Open Source Software Organization">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">RISC-V MCU Open Source Software Organization</div>
            <div class="col-md-8 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/riscv-mcu/" target="_blank" title="RISC-V MCU Open Source Software Organization">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/riscv-mcu/" target="_blank" title="RISC-V MCU Open Source Software Organization">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    

</div>


<div class="container">
    <div class="col-12 col-md-12">
        <div class="row">
            <div class="col-6 col-md-6  x-center">
                <div class="yfq0619 tc labsl">
                    <img src="theme/bg/nuclei-software-platform.png">
                </div>
            </div>
            <div class="col-6 col-md-6">
               
                                  <div class="col-12 col-md-12 mb-2 mt-2 tools">
                       <div class="row">
                           <div class="col-md-6 col-12 x-left">Nuclei Board Labs</div>
                           <div class="col-md-6 col-12 bc1 x-right">
                               <div class="entry">
                                   <div class="items">
                                       
                                       <!--- start  -->
                                                                              <div class="item">
                                           <div class="master">
                                               <a href="https://doc.nucleisys.com/nuclei_board_labs/" target="_blank" title="Nuclei Board Labs">
                                                    <span class="lspan"><img src="/theme/bg/nuclei-blue.png"></span>Online Doc
                                               </a>                                               
                                           </div>                                           
                                       </div>
                                                                              <!--- end  -->
                                                  
                                       <!--- start  --> 
                                                                              <div class="item">
                                           <div class="master">
                                               <a href="https://github.com/Nuclei-Software/nuclei-board-labs" target="_blank" title="Nuclei Board Labs">
                                                    <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                               </a>                                        
                                           </div>                                           
                                       </div>
                                                                              <!--- end  -->
                                       <!--- start  -->
                                                                              <div class="item">
                                         <div class="master">
                                             <a href="https://gitee.com/Nuclei-Software/nuclei-board-labs" target="_blank" title="Nuclei Board Labs">
                                                  <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                                             </a>                                          
                                         </div>                                           
                                       </div>
                                                                              <!--- end  -->    
                                       
                                       <!--- start  -->
                                                                              <!--- end  -->
                                   </div>
                                       
                               </div>
                           </div>
                       </div>    
                   </div>
                                  <div class="col-12 col-md-12 mb-2 mt-2 tools">
                       <div class="row">
                           <div class="col-md-6 col-12 x-left">Nuclei MCU Software Interface Standard (NMSIS)</div>
                           <div class="col-md-6 col-12 bc1 x-right">
                               <div class="entry">
                                   <div class="items">
                                       
                                       <!--- start  -->
                                                                              <div class="item">
                                           <div class="master">
                                               <a href="https://doc.nucleisys.com/nmsis/" target="_blank" title="Nuclei MCU Software Interface Standard (NMSIS)">
                                                    <span class="lspan"><img src="/theme/bg/nuclei-blue.png"></span>Online Doc
                                               </a>                                               
                                           </div>                                           
                                       </div>
                                                                              <!--- end  -->
                                                  
                                       <!--- start  --> 
                                                                              <div class="item">
                                           <div class="master">
                                               <a href="https://github.com/Nuclei-Software/NMSIS" target="_blank" title="Nuclei MCU Software Interface Standard (NMSIS)">
                                                    <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                               </a>                                        
                                           </div>                                           
                                       </div>
                                                                              <!--- end  -->
                                       <!--- start  -->
                                                                              <div class="item">
                                         <div class="master">
                                             <a href="https://gitee.com/Nuclei-Software/NMSIS" target="_blank" title="Nuclei MCU Software Interface Standard (NMSIS)">
                                                  <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                                             </a>                                          
                                         </div>                                           
                                       </div>
                                                                              <!--- end  -->    
                                       
                                       <!--- start  -->
                                                                              <!--- end  -->
                                   </div>
                                       
                               </div>
                           </div>
                       </div>    
                   </div>
                                  <div class="col-12 col-md-12 mb-2 mt-2 tools">
                       <div class="row">
                           <div class="col-md-6 col-12 x-left">Nuclei Linux SDK(Software Development Kit)</div>
                           <div class="col-md-6 col-12 bc1 x-right">
                               <div class="entry">
                                   <div class="items">
                                       
                                       <!--- start  -->
                                                                              <div class="item">
                                           <div class="master">
                                               <a href="https://github.com/Nuclei-Software/nuclei-linux-sdk/#nuclei-linux-sdk" target="_blank" title="Nuclei Linux SDK(Software Development Kit)">
                                                    <span class="lspan"><img src="/theme/bg/nuclei-blue.png"></span>Online Doc
                                               </a>                                               
                                           </div>                                           
                                       </div>
                                                                              <!--- end  -->
                                                  
                                       <!--- start  --> 
                                                                              <div class="item">
                                           <div class="master">
                                               <a href="https://github.com/Nuclei-Software/nuclei-linux-sdk" target="_blank" title="Nuclei Linux SDK(Software Development Kit)">
                                                    <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                               </a>                                        
                                           </div>                                           
                                       </div>
                                                                              <!--- end  -->
                                       <!--- start  -->
                                                                              <div class="item">
                                         <div class="master">
                                             <a href="https://gitee.com/Nuclei-Software/nuclei-linux-sdk" target="_blank" title="Nuclei Linux SDK(Software Development Kit)">
                                                  <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                                             </a>                                          
                                         </div>                                           
                                       </div>
                                                                              <!--- end  -->    
                                       
                                       <!--- start  -->
                                                                              <!--- end  -->
                                   </div>
                                       
                               </div>
                           </div>
                       </div>    
                   </div>
                                  <div class="col-12 col-md-12 mb-2 mt-2 tools">
                       <div class="row">
                           <div class="col-md-6 col-12 x-left">Nuclei SDK For Nuclei 200/300/600/900/1000 Series CPU</div>
                           <div class="col-md-6 col-12 bc1 x-right">
                               <div class="entry">
                                   <div class="items">
                                       
                                       <!--- start  -->
                                                                              <div class="item">
                                           <div class="master">
                                               <a href="https://doc.nucleisys.com/nuclei_sdk/" target="_blank" title="Nuclei SDK For Nuclei 200/300/600/900/1000 Series CPU">
                                                    <span class="lspan"><img src="/theme/bg/nuclei-blue.png"></span>Online Doc
                                               </a>                                               
                                           </div>                                           
                                       </div>
                                                                              <!--- end  -->
                                                  
                                       <!--- start  --> 
                                                                              <div class="item">
                                           <div class="master">
                                               <a href="https://github.com/Nuclei-Software/nuclei-sdk" target="_blank" title="Nuclei SDK For Nuclei 200/300/600/900/1000 Series CPU">
                                                    <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                               </a>                                        
                                           </div>                                           
                                       </div>
                                                                              <!--- end  -->
                                       <!--- start  -->
                                                                              <div class="item">
                                         <div class="master">
                                             <a href="https://gitee.com/Nuclei-Software/nuclei-sdk" target="_blank" title="Nuclei SDK For Nuclei 200/300/600/900/1000 Series CPU">
                                                  <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                                             </a>                                          
                                         </div>                                           
                                       </div>
                                                                              <!--- end  -->    
                                       
                                       <!--- start  -->
                                                                              <!--- end  -->
                                   </div>
                                       
                               </div>
                           </div>
                       </div>    
                   </div>
                                  <div class="col-12 col-md-12 mb-2 mt-2 tools">
                       <div class="row">
                           <div class="col-md-6 col-12 x-left">Nuclei N100 SDK For Nuclei 100 Series CPU</div>
                           <div class="col-md-6 col-12 bc1 x-right">
                               <div class="entry">
                                   <div class="items">
                                       
                                       <!--- start  -->
                                                                              <div class="item">
                                           <div class="master">
                                               <a href="https://doc.nucleisys.com/nuclei_n100_sdk/" target="_blank" title="Nuclei N100 SDK For Nuclei 100 Series CPU">
                                                    <span class="lspan"><img src="/theme/bg/nuclei-blue.png"></span>Online Doc
                                               </a>                                               
                                           </div>                                           
                                       </div>
                                                                              <!--- end  -->
                                                  
                                       <!--- start  --> 
                                                                              <div class="item">
                                           <div class="master">
                                               <a href="https://github.com/Nuclei-Software/nuclei-sdk/tree/master_n100" target="_blank" title="Nuclei N100 SDK For Nuclei 100 Series CPU">
                                                    <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                               </a>                                        
                                           </div>                                           
                                       </div>
                                                                              <!--- end  -->
                                       <!--- start  -->
                                                                              <div class="item">
                                         <div class="master">
                                             <a href="https://gitee.com/Nuclei-Software/nuclei-sdk/tree/master_n100" target="_blank" title="Nuclei N100 SDK For Nuclei 100 Series CPU">
                                                  <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                                             </a>                                          
                                         </div>                                           
                                       </div>
                                                                              <!--- end  -->    
                                       
                                       <!--- start  -->
                                                                              <!--- end  -->
                                   </div>
                                       
                               </div>
                           </div>
                       </div>    
                   </div>
                           </div>
        </div>
    </div>

    

</div>


<div class="container mt-5 subsystem" id="thirdparty">
    <div class="col-md-12 col-12">
        <div class="title"><a href="#thirdparty">Third-Party Software</a></div>
    </div>
</div>


<div class="container mt-5 subsystem">
    <div class="col-md-12 col-12">
        <div class="item item3 clearfix mt-5">
            <div class="nTitle-1">Real-Time Operating System</div>      
            <hr class="hr">
        </div>
    </div>
</div>

<div class="container"> 


    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/freertos.png"></div>
                                        <div class="tname">FreeRTOS</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32b/64b processors</li>
                                            <li>Support 100/200/300/600/900 series</li>
                                            <li>Support real-time fast interrupt scheme ECLIC</li>
                                            <li>Tickless mode supported</li>
                                            <li>Integrated with FreeRTOS 11.1.0 with SMP supported</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Nuclei-Software/nuclei-sdk/tree/master/OS/FreeRTOS" target="_blank" title="FreeRTOS">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/Nuclei-Software/nuclei-sdk/tree/master/OS/FreeRTOS" target="_blank" title="FreeRTOS">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/pcos.png"></div>
                                        <div class="tname">uCOS-II</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Support 100/200/300/600/900/1000 series</li>
                                            <li>Support real-time fast interrupt scheme ECLIC</li>
                                            <li>Integrated with UCOS-II 2.93</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Nuclei-Software/nuclei-sdk/tree/master/OS/UCOSII" target="_blank" title="uCOS-II">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/Nuclei-Software/nuclei-sdk/tree/master/OS/UCOSII" target="_blank" title="uCOS-II">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/rthread.png"></div>
                                        <div class="tname">RT-Thread Nano</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Support 100/200/300/600/900/1000 series</li>
                                            <li>Support real-time fast interrupt scheme ECLIC</li>
                                            <li>Integrated with RT-Thread Nano 3.1.5</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Nuclei-Software/nuclei-sdk/tree/master/OS/RTThread" target="_blank" title="RT-Thread Nano">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/Nuclei-Software/nuclei-sdk/tree/master/OS/RTThread" target="_blank" title="RT-Thread Nano">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/threadx.png"></div>
                                        <div class="tname">ThreadX support is done in Nuclei SDK</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Support 200/300/600/900/1000 series</li>
                                            <li>Support real-time fast interrupt scheme ECLIC</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Nuclei-Software/nuclei-sdk/tree/master/OS/ThreadX" target="_blank" title="ThreadX support is done in Nuclei SDK">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/Nuclei-Software/nuclei-sdk/tree/master/OS/ThreadX" target="_blank" title="ThreadX support is done in Nuclei SDK">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/rthread.png"></div>
                                        <div class="tname">RT-Thread is directly supported in upstream RT-Thread repo</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Support 200/300/600/900 series</li>
                                            <li>Support real-time fast interrupt scheme ECLIC</li>
                                            <li>Upstream supported</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/riscv-mcu/rt-thread/issues/1 " target="_blank" title="RT-Thread is directly supported in upstream RT-Thread repo">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/openharmony.png"></div>
                                        <div class="tname">OpenHarmony Organization</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32 processors</li>
                                            <li>Support 200/300/600/900 series</li>
                                            <li>Support real-time fast interrupt scheme ECLIC</li>
                                            <li>Upstream supported</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/riscv-mcu/kernel_liteos_m" target="_blank" title="OpenHarmony Organization">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/tnecentos.png"></div>
                                        <div class="tname">TencentOS-Tiny is directly supported in upstream repo</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support RISC-V architecture</li>
                                            <li>Support Nuclei bumblebee/n200 series</li>
                                            <li>Upstream supported</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://atomgit.com/tobudos/kernel/tree/master/arch/risc-v/bumblebee/gcc" target="_blank" title="TencentOS-Tiny is directly supported in upstream repo">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/lk.png"></div>
                                        <div class="tname">LittleKernel support is done in fork of littlekernel repo</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32 processors</li>
                                            <li>Support 200/300/600/900 series</li>
                                            <li>Support real-time fast interrupt scheme ECLIC</li>
                                            <li>Upstream PR is still under review</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/littlekernel/lk/pull/281" target="_blank" title="LittleKernel support is done in fork of littlekernel repo">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/NuttX320.png"></div>
                                        <div class="tname">Apache NuttX is done in Nuclei SDK</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Support 200/300/600/900/1000 series</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/riscv-mcu/nuttx/tree/nuclei_trunk/Documentation/platforms/risc-v/nuclei-evalsoc/boards/nuclei-fpga-eval" target="_blank" title="Apache NuttX is done in Nuclei SDK">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/riscv-mcu/nuttx/tree/nuclei_trunk/Documentation/platforms/risc-v/nuclei-evalsoc/boards/nuclei-fpga-eval" target="_blank" title="Apache NuttX is done in Nuclei SDK">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    

</div>




<div class="container mt-5 subsystem">
    <div class="col-md-12 col-12">
        <div class="item item3 clearfix mt-5">
            <div class="nTitle-1">AI Frameworks</div>      
            <hr class="hr">
        </div>
    </div>
</div>

<div class="container"> 


    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/tensorflow.png"></div>
                                        <div class="tname">TF-Lite micro support is deeply integrated and optimized for Nuclei Processors in repo maintained by Nuclei</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Support 200/300/600/900/1000 series</li>
                                            <li>Optimized for B/P/V ISA extension</li>
                                            <li>Deeply integrated with NMSIS-NN library and Nuclei SDK</li>
                                            <li>Can be directly import into Nuclei Studio via NPK solution</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Nuclei-Software/tflite-micro/tree/nuclei_main/tensorflow/lite/micro/nuclei_demosoc" target="_blank" title="TF-Lite micro support is deeply integrated and optimized for Nuclei Processors in repo maintained by Nuclei">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/Nuclei-Software/tflite-micro/tree/nuclei_main/tensorflow/lite/micro/nuclei_demosoc" target="_blank" title="TF-Lite micro support is deeply integrated and optimized for Nuclei Processors in repo maintained by Nuclei">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/sipeed.png"></div>
                                        <div class="tname">Tinymaix support is optimized for Nuclei Processors done by Nuclei</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Optimized for P/V ISA extension</li>
                                            <li>Deeply integrated with Nuclei SDK</li>
                                            <li>Can be directly import into Nuclei Studio via NPK solution</li>
                                            <li>Tinymaix is supported by MaixHub(Model online training platform for edge devices) </li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Nuclei-Software/npk-tinymaix" target="_blank" title="Tinymaix support is optimized for Nuclei Processors done by Nuclei">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com//Nuclei-Software/npk-tinymaix" target="_blank" title="Tinymaix support is optimized for Nuclei Processors done by Nuclei">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/engine.png"></div>
                                        <div class="tname">Tengine-Lite support is optimized for Nuclei Processors done by Tengine team</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32 processors</li>
                                            <li>Support P ISA extension</li>
                                            <li>Deeply integrated with NMSIS NN library</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/openailab/Tengine" target="_blank" title="Tengine-Lite support is optimized for Nuclei Processors done by Tengine team">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/open-ai-lab/tengine" target="_blank" title="Tengine-Lite support is optimized for Nuclei Processors done by Tengine team">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    

</div>





<div class="container mt-5 subsystem">
    <div class="col-md-12 col-12">
        <div class="item item3 clearfix mt-5">
            <div class="nTitle-1">TEE Frameworks</div>      
            <hr class="hr">
        </div>
    </div>
</div>

<div class="container"> 


    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/ipads.png"></div>
                                        <div class="tname">Penglai MCU support is deeply optimized for Nuclei Processors by Trust Kernel</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32 processors</li>
                                            <li>Support Nuclei TEE extension</li>
                                            <li>Commercial solution</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Nuclei-Software/nuclei-linux-sdk/tree/dev_nuclei_penglai" target="_blank" title="Penglai MCU support is deeply optimized for Nuclei Processors by Trust Kernel">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/Nuclei-Software/nuclei-linux-sdk/tree/dev_nuclei_penglai" target="_blank" title="Penglai MCU support is deeply optimized for Nuclei Processors by Trust Kernel">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                        
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/penglai.png"></div>
                                        <div class="tname">Penglai PMP/sPMP support is deeply optimized for Nuclei Processors in Nuclei Linux SDK</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 64 processors</li>
                                            <li>Support 600/900 series</li>
                                            <li>Support Nuclei TEE extension</li>
                                            <li>opensource solution</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Penglai-Enclave/Penglai-Enclave/" target="_blank" title="Penglai PMP/sPMP support is deeply optimized for Nuclei Processors in Nuclei Linux SDK">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/Penglai-Enclave/Penglai-Enclave/" target="_blank" title="Penglai PMP/sPMP support is deeply optimized for Nuclei Processors in Nuclei Linux SDK">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                        
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/keystone.png"></div>
                                        <div class="tname">Keystone Enclave support is deeply optimized for Nuclei Processors in Nuclei Linux SDK</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 64 processors</li>
                                            <li>Support RISC-V PMP extension</li>
                                            <li>Opensource solution</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Nuclei-Software/nuclei-linux-sdk/tree/dev_nuclei_keystone " target="_blank" title="Keystone Enclave support is deeply optimized for Nuclei Processors in Nuclei Linux SDK">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/Nuclei-Software/nuclei-linux-sdk/tree/dev_nuclei_keystone" target="_blank" title="Keystone Enclave support is deeply optimized for Nuclei Processors in Nuclei Linux SDK">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <!--- end  -->
                        
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/tee.png"></div>
                                        <div class="tname">OpTEE support is deeply optimized for Nuclei Processors in Nuclei Linux SDK</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 64 processors</li>
                                            <li>Support RISC-V PMP extension and also Nuclei secure feature</li>
                                            <li>Opensource to RISC-V ecosystem by Nuclei</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Nuclei-Software/nuclei-linux-sdk/blob/feature/optee_5.10/optee/README.md" target="_blank" title="OpTEE support is deeply optimized for Nuclei Processors in Nuclei Linux SDK">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/OP-TEE/optee_os/issues/6173" target="_blank" title="OpTEE support is deeply optimized for Nuclei Processors in Nuclei Linux SDK">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    

</div>




<div class="container mt-5 subsystem">
    <div class="col-md-12 col-12">
        <div class="item item3 clearfix mt-5">
            <div class="nTitle-1">3rd Party Tools</div>      
            <hr class="hr">
        </div>
    </div>
</div>

<div class="container"> 


    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/iar.png"></div>
                                        <div class="tname">IAR Workbench support is deeply optimized for Nuclei Processors</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Support Nuclei 100/200/300/600/900/1000 series</li>
                                            <li>IAR Prebuilt Projects integrated in Nuclei SDK/Nuclei N100 SDK/NMSIS</li>
                                            <li>Commercial product</li>
                                        </ul>
                    
                                        <ul class="tips">
                                            <li><a href="https://github.com/Nuclei-Software/nuclei-sdk/tree/master/ideprojects/iar" target="_blank">Using prebuilt IAR Nuclei SDK Projects</a></li>
                                            <li><a href="https://github.com/Nuclei-Software/NMSIS/tree/master/NMSIS/ideprojects/iar" target="_blank">Using prebuilt IAR NMSIS DSP/NN Library Projects</a></li>
                                        </ul>
                                        
                </div>
                        
            </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.iar.com/iar-embedded-workbench/#!?architecture=RISC-V" target="_blank" title="IAR Workbench support is deeply optimized for Nuclei Processors">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/terapines.png"></div>
                                        <div class="tname">Terapines support is optimized for Nuclei Processors</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Support IMAFDCBPKV/Zc/Xxldsp/Xxlcz extension</li>
                                            <li>Provide better performance compared to gcc/clang</li>
                                            <li>High performance auto-vectorization for RISC-V V and P extension</li>
                                            <li>High performance and density DSP libraries</li>
                                            <li>Cycle accurate SoC virtual prototyping tools support Nuclei IP cores</li>
                                            <li>Deeply integrated in Nuclei SDK and Nuclei Studio with Terapines ZCC</li>
                                            <li>Commercial Pro version and Free Lite version</li>
                                        </ul>
                    
                                        <ul class="tips">
                                            <li><a href="https://1nfinite.ai/t/terapines-zcc-risc-v/70" target="_blank">Using Terapines ZCC for Nuclei RISC-V Processors</a></li>
                                            <li><a href="https://1nfinite.ai/t/zstudio-ide-risc-v/71" target="_blank">Using Terapines ZStudio for Nuclei RISC-V Processors</a></li>
                                        </ul>
                                        
                </div>
                        
            </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.terapines.com/" target="_blank" title="Terapines support is optimized for Nuclei Processors">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/segger.png"></div>
                                        <div class="tname">Segger Embedded Studio support is deeply optimized for Nuclei Processors</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Support Nuclei 200/300/600/900/1000 series</li>
                                            <li>Optimized C/C++ runtime library for RISC-V processors</li>
                                            <li>Segger quick start projects provided by Nuclei is available</li>
                                            <li>Commercial product</li>
                                        </ul>
                    
                                        <ul class="tips">
                                            <li><a href="https://www.nucleisys.com/upload/files/doc/ses/Nuclei_SES_IDE_Installation_202008.pdf" target="_blank">Installation Manual for Nuclei Processor Core: Nuclei_SES_IDE_Installation.pdf</a></li>
                                            <li><a href="https://www.nucleisys.com/upload/files/doc/ses/Nuclei_SES_IDE_QuickStart_202008.pdf" target="_blank">QuickStart Manual for Nuclei Processor Core: Nuclei_SES_IDE_QuickStart.pdf</a></li>
                                            <li><a href="https://github.com/riscv-mcu/nuclei_sesprojects" target="_blank">Nuclei RISC-V Simple Segger Embedded Studio Projects</a></li>
                                        </ul>
                                        
                </div>
                        
            </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.segger.com/products/development-tools/embedded-studio/" target="_blank" title="Segger Embedded Studio support is deeply optimized for Nuclei Processors">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/lauterbach.png"></div>
                                        <div class="tname">Lauterbach support is deeply optimized for Nuclei Processors</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Support Nuclei 200/300/600/900 series</li>
                                            <li>Support Debug and Trace in Nuclei Processors</li>
                                            <li>Commercial product</li>
                                        </ul>
                    
                                        
                </div>
                        
            </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.lauterbach.com/" target="_blank" title="Lauterbach support is deeply optimized for Nuclei Processors">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/siemens.png"></div>
                                        <div class="tname">Siemens Tessent Enhanced Trace Encoder solution</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V E-Trace Solution</li>
                                        </ul>
                    
                                        
                </div>
                        
            </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.nucleisys.com/newsdetail.php?id=310" target="_blank" title="Siemens Tessent Enhanced Trace Encoder solution">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/platformio.png"></div>
                                        <div class="tname">PlatformIO support is deeply optimized for Nuclei Processors</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Support Nuclei 200/300/600/900 Series</li>
                                            <li>Support gd32vf103 and gd32vw55x SoC via Nuclei SDK</li>
                                        </ul>
                    
                                        
                </div>
                        
            </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/Nuclei-Software/platform-nuclei" target="_blank" title="PlatformIO support is deeply optimized for Nuclei Processors">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/Nuclei-Software/platform-nuclei" target="_blank" title="PlatformIO support is deeply optimized for Nuclei Processors">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    

</div>



<div class="container mt-5 subsystem">
    <div class="col-md-12 col-12">
        <div class="item item3 clearfix mt-5">
            <div class="nTitle-1">SystemC Modeling</div>      
            <hr class="hr">
        </div>
    </div>
</div>

<div class="container"> 

    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/nuclei.png"></div>
                                        <div class="tname">Nuclei in house developed SystemC function Model</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors </li>
                                            <li>Based on QEMU, and open source </li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <div class="item">
                            <div class="master">
                                <a href="https://github.com/riscv-mcu/nuclei_vp" target="_blank" title="Nuclei in house developed SystemC function Model">
                                     <span class="lspan"><img src="/theme/bg/github-blue.png"></span>Github 
                                </a>                                        
                            </div>                                           
                        </div>
                                                <!--- end  -->
                        <!--- start  -->
                                                <div class="item">
                          <div class="master">
                              <a href="https://gitee.com/riscv-mcu/nuclei_vp" target="_blank" title="Nuclei in house developed SystemC function Model">
                                   <span class="lspan"><img src="/theme/bg/gitee-red.png"></span>Gitee
                              </a>                                          
                          </div>                                           
                        </div>
                                                <!--- end  -->    
                        <!--- start  -->
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/nuclei.png"></div>
                                        <div class="tname">Nuclei in house developed SystemC Near Cycle Model</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Near cycle model,  support gprof</li>
                                            <li>Still in development</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://doc.nucleisys.com/nuclei_tools/xlmodel/intro.html" target="_blank" title="Nuclei in house developed SystemC Near Cycle Model">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/simango.png"></div>
                                        <div class="tname">SIMANGO(芯芒科技) Mosim SystemC Simulation Solution</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Provide QEMU SystemC function model</li>
                                            <li>Provide RTL Verilator converted accurate SystemC model</li>
                                            <li>Provide SoC simulation support</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.nucleisys.com/newsdetail.php?id=326" target="_blank" title="SIMANGO(芯芒科技) Mosim SystemC Simulation Solution">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-12 col-md-12 mb-2 mt-2 tools">
        <div class="row">
            <div class="col-md-4 col-12 x-left">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/machineware.png"></div>
                                        <div class="tname">MachineWare Virtual Prototyping</div>
                </div>
            </div>
            <div class="col-md-4 col-12 x-left">
                            <div class="bc1">
                    <ul>
                                            <li>Support Nuclei RISC-V 32/64 processors</li>
                                            <li>Provide SIM-V SystemC function model faster than QEMU</li>
                                            <li>Provide QEMU based SystemC model</li>
                                            <li>Provide full system simulation or virtual platform</li>
                                        </ul>
                </div>
                        </div>
            <div class="col-md-4 col-12 bc1 x-right">
                <div class="entry">
                    <div class="items">
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.nucleisys.com/newsdetail.php?id=318" target="_blank" title="MachineWare Virtual Prototyping">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    

</div>







<div class="container mt-5 subsystem">
    <div class="col-md-12 col-12">
        <div class="item item3 clearfix mt-5">
            <div class="nTitle-1">Automobile Ecosystem</div>      
            <hr class="hr">
        </div>
    </div>
</div>

<div class="container"> 

<div class="row">
    <div class="col-6 col-md-4 mb-2 mt-2">
        <div class="row tools ftools">
            <div class="col-md-12 col-12 x-center">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/iar.png"></div>
                                        <div class="tname">IAR: Embedded Workbench, Compiler & Debug Toolchain</div>
                </div>
            </div>
            <div class="col-md-12 col-12 x-center">
                        </div>
            <div class="col-md-12 col-12 bc1 x-center">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.nucleisys.com/newsdetail.php?id=318" target="_blank" title="IAR: Embedded Workbench, Compiler & Debug Toolchain">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-6 col-md-4 mb-2 mt-2">
        <div class="row tools ftools">
            <div class="col-md-12 col-12 x-center">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/jingwei.png"></div>
                                        <div class="tname">Hirain(经纬恒润) AUTOSAR Product</div>
                </div>
            </div>
            <div class="col-md-12 col-12 x-center">
                        </div>
            <div class="col-md-12 col-12 bc1 x-center">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://nucleisys.com/newsdetail.php?id=319" target="_blank" title="Hirain(经纬恒润) AUTOSAR Product">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-6 col-md-4 mb-2 mt-2">
        <div class="row tools ftools">
            <div class="col-md-12 col-12 x-center">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/machineware.png"></div>
                                        <div class="tname">Machineware SIM-V SystemC Virtual Platform</div>
                </div>
            </div>
            <div class="col-md-12 col-12 x-center">
                        </div>
            <div class="col-md-12 col-12 bc1 x-center">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.machineware.de/pages/products.html#riscv" target="_blank" title="Machineware SIM-V SystemC Virtual Platform">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-6 col-md-4 mb-2 mt-2">
        <div class="row tools ftools">
            <div class="col-md-12 col-12 x-center">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/simango.png"></div>
                                        <div class="tname">Simango(星芒科技) Mosim SystemC Virtual Platform</div>
                </div>
            </div>
            <div class="col-md-12 col-12 x-center">
                        </div>
            <div class="col-md-12 col-12 bc1 x-center">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.nucleisys.com/newsdetail.php?id=326" target="_blank" title="Simango(星芒科技) Mosim SystemC Virtual Platform">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-6 col-md-4 mb-2 mt-2">
        <div class="row tools ftools">
            <div class="col-md-12 col-12 x-center">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/tasking.png"></div>
                                        <div class="tname">Tasking: VX-Toolset, Compiler; Debugger</div>
                </div>
            </div>
            <div class="col-md-12 col-12 x-center">
                        </div>
            <div class="col-md-12 col-12 bc1 x-center">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.tasking.com/" target="_blank" title="Tasking: VX-Toolset, Compiler; Debugger">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-6 col-md-4 mb-2 mt-2">
        <div class="row tools ftools">
            <div class="col-md-12 col-12 x-center">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/greenhills.png"></div>
                                        <div class="tname">GreenHills</div>
                </div>
            </div>
            <div class="col-md-12 col-12 x-center">
                        </div>
            <div class="col-md-12 col-12 bc1 x-center">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.ghs.com/" target="_blank" title="GreenHills">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-6 col-md-4 mb-2 mt-2">
        <div class="row tools ftools">
            <div class="col-md-12 col-12 x-center">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/vector.png"></div>
                                        <div class="tname">Vector: MICROSAR, AUTOSAR</div>
                </div>
            </div>
            <div class="col-md-12 col-12 x-center">
                        </div>
            <div class="col-md-12 col-12 bc1 x-center">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.vector.com/" target="_blank" title="Vector: MICROSAR, AUTOSAR">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-6 col-md-4 mb-2 mt-2">
        <div class="row tools ftools">
            <div class="col-md-12 col-12 x-center">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/safertos.png"></div>
                                        <div class="tname">FreeRTOS: SafeRTOS, AUTOSAR</div>
                </div>
            </div>
            <div class="col-md-12 col-12 x-center">
                        </div>
            <div class="col-md-12 col-12 bc1 x-center">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://www.freertos.org/zh-cn-cmn-s/" target="_blank" title="FreeRTOS: SafeRTOS, AUTOSAR">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    <div class="col-6 col-md-4 mb-2 mt-2">
        <div class="row tools ftools">
            <div class="col-md-12 col-12 x-center">
                <div class="cell">
                                        <div class="tlogo"><img width="" src="/theme/bg/download/hightec.png"></div>
                                        <div class="tname">Hightec</div>
                </div>
            </div>
            <div class="col-md-12 col-12 x-center">
                        </div>
            <div class="col-md-12 col-12 bc1 x-center">
                <div class="entry">
                    <div class="items">
                        
                        <!--- start  -->
                                                <!--- end  -->
                                   
                        <!--- start  --> 
                                                <!--- end  -->
                        <!--- start  -->
                                                <!--- end  -->    
                        <!--- start  -->
                                                <div class="item">
                            <div class="master">
                                <a href="https://hightec-rt.com/products/development-platform" target="_blank" title="Hightec">
                                     <span class="lspan"><img src="/theme/bg/out.png"></span>More
                                </a>                                               
                            </div>                                           
                        </div>
                                                <!--- end  -->
                    </div>
                        
                </div>
            </div>
        </div>    
    </div>
    
</div>
</div>

<link rel="stylesheet" type="text/css" href="/theme/css/footer.css?_t=202508201100" />
<div class="incfooter">
    <div class="bg3">
        <div class="wrap2">
            <div class="nPartner-1">
                <div class="nTitle-1 tc">Partners<span style="font-family:微软雅黑;font-size: 16px;color: #c0c0c0;">（排名不分先后）</span></div>
                <div class="tc">
                    
                    <div class="row">
                        
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2019/12/1575447191-2835.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">RISC-V Foundation</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2019/12/1575447243-5142.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">SICA</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2019/12/1575447270-3479.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">China RISC-V Industry Alliance</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2019/12/1575447294-86.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">China RISC-V Alliance</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/04/1680516423-1308.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">SZICC</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2020/03/1584173156-7491.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">HBSIA</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2020/03/1584173672-553.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">CBSIA</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2025/03/1742452249-86.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">SOPIC</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2020/03/1584172741-7167.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">武汉光电工业技术研究院</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2019/12/1575447319-871.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">Amlogic</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2019/12/1575447338-3794.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">VeriSilicon</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2019/12/1575447463-9071.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">LAUTERBACH</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2019/12/1575628198-3748.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">TencentOS Tiny</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673941863-1997.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">OpenHarmony</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2020/02/1581487215-903.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">PlatformIO</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2020/03/1583995661-5928.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">SEGGER</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2025/06/1751254607-5726.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">MUCSE</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2025/06/1751254458-954.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">ORITEK</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2025/06/1751254953-1357.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">Brite</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2025/06/1751254740-7499.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">Innochip Technology</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2025/03/1742892285-720.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">格见构知</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2025/03/1742454364-9213.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">AistarTek</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/04/1712821040-5431.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">exide</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2025/03/1742452368-4933.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">HighTec</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/04/1712821182-8408.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">CALTERAH</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/04/1712821134-5923.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">BinarySemi</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/04/1712821350-8408.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">X-EPIC</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/04/1712821323-597.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">SILERGY</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/04/1712821081-6245.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">MachineWare</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/04/1712821280-812.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">SIMANGO</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2020/03/1584170344-4437.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">TrustKernel</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673942107-9008.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">XIAOMI</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/04/1712821240-3140.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">JINGWEI HIRAIN</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/03/1710122055-7695.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">SIEMENS EDA</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/03/1710122187-6734.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">Motorcomm</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/03/1710122232-5099.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">CHIPWAYS</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2024/03/1710122400-4863.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">SWID</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943603-1132.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">taolink-tech</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943578-8420.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">GeoforceChip</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943522-133.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">ChipIntelli</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943490-1665.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">Witmem</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943452-3220.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">Fisilink</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943418-5380.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">TIH Microelectronics</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943399-2357.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">XinSheng Tech</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943374-7102.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">GigaDevice</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943346-3957.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">ASR</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943315-1986.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">AnLogic</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2019/12/1575447419-9074.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">TusStar</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2020/03/1584172485-5769.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">Mocro & Nano Institute</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2020/10/1602836467-1510.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">RT-Thread</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2020/10/1602836819-3604.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">OPEN AI LAB</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2020/12/1608015550-4112.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">IAR</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943631-6489.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">HUST</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943647-8567.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">SJTU</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943740-7156.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">WHU</h3>
                                    </div>
                                </div>
                                                        <div class="col-md-3 col-4">
                                    <div class="cell">
                                        <div class=""><img width="" src="/upload/image/2023/01/1673943763-2279.png?_t=202508201100"/></div>
                                        <h3 style="font-size: 14px;">HBUT</h3>
                                    </div>
                                </div>
                         

                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="nFooter" style="clear: left;">
        <div class="section section_type5 " id="section6" style="">
            <div class="info clearfix">
                <h3 class="title">Contact Us</h3>
                <div class="right">
                    <div class="clearfix info2 ">
                        <div class="entry ">
                            <div class="icon ico-mail">&nbsp;</div>
                            <h4>Email</h4>
                            <h3 class="add" style="padding-top: 0px;">
                                <em style="padding-bottom: 10px;display: block;font-size: 14px;">contact@nucleisys.com</em>
                            </h3>
                            
                            <div class="icon ico-message">&nbsp;</div>
                            <h4>Leave a Message</h4>
                            <h3 class="add" style="padding-top: 5px;">
                                <em><a href="/contact.php?t=1" target="_blank">Sales<i class="fa fa-hand-o-left" aria-hidden="true"></i></a></em>
                                <em><a href="/contact.php?t=2" target="_blank">Academic<i class="fa fa-hand-o-left" aria-hidden="true"></i></a></em>
                            </h3>
                        </div>
                        
                        <div class="entry ">
                            <div class="icon ico-code">&nbsp;</div>
                            <h4>Follow us on</h4>
                            <div class="code">
                                <div class="img"><img src="/upload/image/2019/04/1556273171-44.png" /></div>
                                <h6></h6>
                            </div>
                            <div class="code">
                                <div class="img"><img src="/upload/image/2019/04/1556273241-7462.png" /></div>
                                <h6></h6>
                            </div>
                        </div>
                        <div class="entry ">
                            <div class="icon ico-34">&nbsp;</div>
                            <h4>Address</h4>
                            <h3 class="add">
                                <em>Shanghai: 8/F, Sandhill Central, No. 505 ZhangJiang Road, Pudong Dis, Shanghai</em>
                                <em>Wuhan: 9/Fth, GaoXin Building, No.2 Muxiang Road, Hongshan Dis, Wuhan, Hubei</em> 
                                <em>Beijing: IC PARK, No.9 Fenghao Road, Haidian Dis, Beijing</em>
                                <em></em>
                                <em></em>
                            </h3>
                        </div>
                    </div>
                </div>
            </div>
            
            
            </div>

        <div class="copy">
            <div class="wrap2">
                Copyright © 2018-2025 Nuclei System (or its affiliates)<br /><a href="https://beian.miit.gov.cn" target="_blank"><p style="color:rgba(255, 255, 255, 0.5);">鄂ICP备18019458号-1</p></a> 
            </div>
        </div>
    </div>
    
    <style>
    
    /*gotop*/
    .cbbfixed {position: fixed;right: 20px;transition: bottom ease .3s;bottom: -85px;z-index: 3;cursor:pointer;}
    .cbbfixed .cbbtn {width: 40px;height: 40px;display: block;background-color: #274091;border-radius:4px}
    .cbbfixed .gotop .up-icon{float:left;margin:0px 0 0 9px;width:23px;height:12px;font-size: 35px;color: #ffffff;}
    
    </style>
    <script>
    
    function chinaz(){
        this.init();
    }
    chinaz.prototype = {
        constructor: chinaz,
        init: function(){
            this._initBackTop();
        },
        _initBackTop: function(){
            var $backTop = this.$backTop = $('<div class="cbbfixed">'+
            '<a class="gotop cbbtn">'+
            '<span class="up-icon"><i class="fa fa-angle-up" aria-hidden="true"></i></span>'+
            '</a>'+
            '</div>');
            $('body').append($backTop);
    
            $backTop.click(function(){
                $("html, body").animate({
                    scrollTop: 0
                }, 120);
            });
    
            var timmer = null;
            $(window).bind("scroll",function() {
                var d = $(document).scrollTop(),
                    e = $(window).height();
                0 < d ? $backTop.css("bottom", "10px") : $backTop.css("bottom", "-90px");
                clearTimeout(timmer);
                timmer = setTimeout(function() {
                    clearTimeout(timmer)
                },100);
            });
        }
    
    }
    var chinaz = new chinaz();
    </script>
    
    <script>
    var _hmt = _hmt || [];
    (function() {
      var hm = document.createElement("script");
      hm.src = "https://hm.baidu.com/hm.js?aae390378351f2cf6dda7f9d7bcb9df9";
      var s = document.getElementsByTagName("script")[0]; 
      s.parentNode.insertBefore(hm, s);
    })();
    </script>
    <script>
    (function(){
        var bp = document.createElement('script');
        var curProtocol = window.location.protocol.split(':')[0];
        if (curProtocol === 'https') {
            bp.src = 'https://zz.bdstatic.com/linksubmit/push.js';
        }
        else {
            bp.src = 'http://push.zhanzhang.baidu.com/push.js';
        }
        var s = document.getElementsByTagName("script")[0];
        s.parentNode.insertBefore(bp, s);
    })();
    </script>
    <script type="text/javascript">
      var _paq = window._paq = window._paq || [];
      /* tracker methods like "setCustomDimension" should be called before "trackPageView" */
      _paq.push(["setDocumentTitle", document.domain + "/" + document.title]);
      _paq.push(["setDomains", ["*.www.nucleisys.com"]]);
      _paq.push(['trackPageView']);
      _paq.push(['enableLinkTracking']);
      (function() {
        var u="//matomo.nucleisys.com/";
        _paq.push(['setTrackerUrl', u+'matomo.php']);
        _paq.push(['setSiteId', '2']);
        var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
        g.type='text/javascript'; g.async=true; g.src=u+'matomo.js'; s.parentNode.insertBefore(g,s);
      })();
    </script>


    <script src="/theme/js/library.js?_t=202508201100"></script>
    <script src="/theme/js/Validform_v5.3.2.js?_t=202508201100"></script>
    <script src="/layer/layer.js?_t=202508201100"></script>
    <script src="/theme/js/action.js?_t=202508201100"></script>
</div>        </body>

<script>
function myFunction(){
	layer.msg('请先登录!')
	//alert('请先登录');
	//window.location.href="/login.php";
}

$('.versionSelect').click(function () {
    $(this).parents(".item").children(".versionList").slideToggle('fast')
    $(document).click(function () {
        $(this).parents("item").children(".versionList").slideUp('fast')
    })
    return false
})

$('.versionList').parents(".item").mouseleave(function () {
    $(this).children(".versionList").slideUp('fast')
    return false
})
</script>

</html>