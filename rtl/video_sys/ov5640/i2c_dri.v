//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�http://www.openedv.com/forum.php
//�Ա����̣�https://zhengdianyuanzi.tmall.com
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2023-2033
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           i2c_dri
// Last modified Date:  2020/05/04 9:19:08
// Last Version:        V1.0
// Descriptions:        IIC����
//                      
//----------------------------------------------------------------------------------------
// Created by:          ����ԭ��
// Created date:        2019/05/04 9:19:08
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module i2c_dri
    #(
      parameter   SLAVE_ADDR = 7'b1010000   ,  //EEPROM�ӻ���ַ
      parameter   CLK_FREQ   = 26'd50_000_000, //ģ�������ʱ��Ƶ��
      parameter   I2C_FREQ   = 18'd250_000     //IIC_SCL��ʱ��Ƶ��
    )
   (                                                            
    input                clk        ,    
    input                rst_n      ,   
                                         
    //i2c interface                      
    input                i2c_exec   ,  //I2C����ִ���ź�
    input                bit_ctrl   ,  //�ֵ�ַλ����(16b/8b)
    input                i2c_rh_wl  ,  //I2C��д�����ź�
    input        [15:0]  i2c_addr   ,  //I2C�����ڵ�ַ
    input        [7:0]   i2c_data_w ,  //I2CҪд������
    output  reg  [7:0]   i2c_data_r ,  //I2C����������
    output  reg          i2c_done   ,  //I2Cһ�β������
    output  reg          i2c_ack    ,  //I2CӦ���־ 0:Ӧ�� 1:δӦ��
    output  reg          scl        ,  //I2C��SCLʱ���ź�
    inout                sda        ,  //I2C��SDA�ź�
                                       
    //user interface                   
    output  reg          dri_clk       //����I2C����������ʱ��
     );

//localparam define
localparam  st_idle     = 8'b0000_0001; //����״̬
localparam  st_sladdr   = 8'b0000_0010; //����������ַ(slave address)
localparam  st_addr16   = 8'b0000_0100; //����16λ�ֵ�ַ
localparam  st_addr8    = 8'b0000_1000; //����8λ�ֵ�ַ
localparam  st_data_wr  = 8'b0001_0000; //д����(8 bit)
localparam  st_addr_rd  = 8'b0010_0000; //����������ַ��
localparam  st_data_rd  = 8'b0100_0000; //������(8 bit)
localparam  st_stop     = 8'b1000_0000; //����I2C����

//reg define
reg            sda_dir   ; //I2C����(SDA)�������
reg            sda_out   ; //SDA����ź�
reg            st_done   ; //״̬����
reg            wr_flag   ; //д��־
reg    [ 6:0]  cnt       ; //����
reg    [ 7:0]  cur_state ; //״̬����ǰ״̬
reg    [ 7:0]  next_state; //״̬����һ״̬
reg    [15:0]  addr_t    ; //��ַ
reg    [ 7:0]  data_r    ; //��ȡ������
reg    [ 7:0]  data_wr_t ; //I2C��д�����ݵ���ʱ�Ĵ�
reg    [ 9:0]  clk_cnt   ; //��Ƶʱ�Ӽ���

//wire define
wire          sda_in     ; //SDA�����ź�
wire   [8:0]  clk_divide ; //ģ������ʱ�ӵķ�Ƶϵ��

//*****************************************************
//**                    main code
//*****************************************************

//SDA����
assign  sda     = sda_dir ?  sda_out : 1'bz;     //SDA������������
assign  sda_in  = sda ;                          //SDA��������
assign  clk_divide = (CLK_FREQ/I2C_FREQ) >> 2'd2;//ģ������ʱ�ӵķ�Ƶϵ��

//����I2C��SCL���ı�Ƶ�ʵ�����ʱ����������i2c�Ĳ���
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        dri_clk <=  1'b0;
        clk_cnt <= 10'd0;
    end
    else if(clk_cnt == clk_divide[8:1] - 1'd1) begin
        clk_cnt <= 10'd0;
        dri_clk <= ~dri_clk;
    end
    else
        clk_cnt <= clk_cnt + 1'b1;
end

//(����ʽ״̬��)ͬ��ʱ������״̬ת��
always @(posedge dri_clk or negedge rst_n) begin
    if(!rst_n)
        cur_state <= st_idle;
    else
        cur_state <= next_state;
end

//����߼��ж�״̬ת������
always @(*) begin
    next_state = st_idle;
    case(cur_state)
        st_idle: begin                          //����״̬
           if(i2c_exec) begin
               next_state = st_sladdr;
           end
           else
               next_state = st_idle;
        end
        st_sladdr: begin
            if(st_done) begin
                if(bit_ctrl)                    //�ж���16λ����8λ�ֵ�ַ
                   next_state = st_addr16;
                else
                   next_state = st_addr8 ;
            end
            else
                next_state = st_sladdr;
        end
        st_addr16: begin                        //д16λ�ֵ�ַ
            if(st_done) begin
                next_state = st_addr8;
            end
            else begin
                next_state = st_addr16;
            end
        end
        st_addr8: begin                         //8λ�ֵ�ַ
            if(st_done) begin
                if(wr_flag==1'b0)               //��д�ж�
                    next_state = st_data_wr;
                else
                    next_state = st_addr_rd;
            end
            else begin
                next_state = st_addr8;
            end
        end
        st_data_wr: begin                       //д����(8 bit)
            if(st_done)
                next_state = st_stop;
            else
                next_state = st_data_wr;
        end
        st_addr_rd: begin                       //д��ַ�Խ��ж�����
            if(st_done) begin
                next_state = st_data_rd;
            end
            else begin
                next_state = st_addr_rd;
            end
        end
        st_data_rd: begin                       //��ȡ����(8 bit)
            if(st_done)
                next_state = st_stop;
            else
                next_state = st_data_rd;
        end
        st_stop: begin                          //����I2C����
            if(st_done)
                next_state = st_idle;
            else
                next_state = st_stop ;
        end
        default: next_state= st_idle;
    endcase
end

//ʱ���·����״̬���
always @(posedge dri_clk or negedge rst_n) begin
    //��λ��ʼ��
    if(!rst_n) begin
        scl       <= 1'b1;
        sda_out   <= 1'b1;
        sda_dir   <= 1'b1;                          
        i2c_done  <= 1'b0;                          
        i2c_ack   <= 1'b0;                          
        cnt       <= 1'b0;                          
        st_done   <= 1'b0;                          
        data_r    <= 1'b0;                          
        i2c_data_r<= 1'b0;                          
        wr_flag   <= 1'b0;                          
        addr_t    <= 1'b0;                          
        data_wr_t <= 1'b0;                          
    end                                              
    else begin                                       
        st_done <= 1'b0 ;                            
        cnt     <= cnt +1'b1 ;                       
        case(cur_state)                              
             st_idle: begin                          //����״̬
                scl     <= 1'b1;                     
                sda_out <= 1'b1;                     
                sda_dir <= 1'b1;                     
                i2c_done<= 1'b0;                     
                cnt     <= 7'b0;               
                if(i2c_exec) begin                   
                    wr_flag   <= i2c_rh_wl ;         
                    addr_t    <= i2c_addr  ;         
                    data_wr_t <= i2c_data_w;  
                    i2c_ack <= 1'b0;                      
                end                                  
            end                                      
            st_sladdr: begin                         //д��ַ(������ַ���ֵ�ַ)
                case(cnt)                            
                    7'd1 : sda_out <= 1'b0;          //��ʼI2C
                    7'd3 : scl <= 1'b0;              
                    7'd4 : sda_out <= SLAVE_ADDR[6]; //����������ַ
                    7'd5 : scl <= 1'b1;              
                    7'd7 : scl <= 1'b0;              
                    7'd8 : sda_out <= SLAVE_ADDR[5]; 
                    7'd9 : scl <= 1'b1;              
                    7'd11: scl <= 1'b0;              
                    7'd12: sda_out <= SLAVE_ADDR[4]; 
                    7'd13: scl <= 1'b1;              
                    7'd15: scl <= 1'b0;              
                    7'd16: sda_out <= SLAVE_ADDR[3]; 
                    7'd17: scl <= 1'b1;              
                    7'd19: scl <= 1'b0;              
                    7'd20: sda_out <= SLAVE_ADDR[2]; 
                    7'd21: scl <= 1'b1;              
                    7'd23: scl <= 1'b0;              
                    7'd24: sda_out <= SLAVE_ADDR[1]; 
                    7'd25: scl <= 1'b1;              
                    7'd27: scl <= 1'b0;              
                    7'd28: sda_out <= SLAVE_ADDR[0]; 
                    7'd29: scl <= 1'b1;              
                    7'd31: scl <= 1'b0;              
                    7'd32: sda_out <= 1'b0;          //0:д
                    7'd33: scl <= 1'b1;              
                    7'd35: scl <= 1'b0;              
                    7'd36: begin                     
                        sda_dir <= 1'b0;             
                        sda_out <= 1'b1;                         
                    end                              
                    7'd37: scl     <= 1'b1;            
                    7'd38: begin                     //�ӻ�Ӧ�� 
                        st_done <= 1'b1;
                        if(sda_in == 1'b1)           //�ߵ�ƽ��ʾδӦ��
                            i2c_ack <= 1'b1;         //����Ӧ���־λ     
                    end                                          
                    7'd39: begin                     
                        scl <= 1'b0;                 
                        cnt <= 1'b0;                 
                    end                              
                    default :  ;                     
                endcase                              
            end                                      
            st_addr16: begin                         
                case(cnt)                            
                    7'd0 : begin                     
                        sda_dir <= 1'b1 ;            
                        sda_out <= addr_t[15];       //�����ֵ�ַ
                    end                              
                    7'd1 : scl <= 1'b1;              
                    7'd3 : scl <= 1'b0;              
                    7'd4 : sda_out <= addr_t[14];    
                    7'd5 : scl <= 1'b1;              
                    7'd7 : scl <= 1'b0;              
                    7'd8 : sda_out <= addr_t[13];    
                    7'd9 : scl <= 1'b1;              
                    7'd11: scl <= 1'b0;              
                    7'd12: sda_out <= addr_t[12];    
                    7'd13: scl <= 1'b1;              
                    7'd15: scl <= 1'b0;              
                    7'd16: sda_out <= addr_t[11];    
                    7'd17: scl <= 1'b1;              
                    7'd19: scl <= 1'b0;              
                    7'd20: sda_out <= addr_t[10];    
                    7'd21: scl <= 1'b1;              
                    7'd23: scl <= 1'b0;              
                    7'd24: sda_out <= addr_t[9];     
                    7'd25: scl <= 1'b1;              
                    7'd27: scl <= 1'b0;              
                    7'd28: sda_out <= addr_t[8];     
                    7'd29: scl <= 1'b1;              
                    7'd31: scl <= 1'b0;              
                    7'd32: begin                     
                        sda_dir <= 1'b0;             
                        sda_out <= 1'b1;   
                    end                              
                    7'd33: scl  <= 1'b1;             
                    7'd34: begin                     //�ӻ�Ӧ��
                        st_done <= 1'b1;     
                        if(sda_in == 1'b1)           //�ߵ�ƽ��ʾδӦ��
                            i2c_ack <= 1'b1;         //����Ӧ���־λ    
                    end        
                    7'd35: begin                     
                        scl <= 1'b0;                 
                        cnt <= 1'b0;                 
                    end                              
                    default :  ;                     
                endcase                              
            end                                      
            st_addr8: begin                          
                case(cnt)                            
                    7'd0: begin                      
                       sda_dir <= 1'b1 ;             
                       sda_out <= addr_t[7];         //�ֵ�ַ
                    end                              
                    7'd1 : scl <= 1'b1;              
                    7'd3 : scl <= 1'b0;              
                    7'd4 : sda_out <= addr_t[6];     
                    7'd5 : scl <= 1'b1;              
                    7'd7 : scl <= 1'b0;              
                    7'd8 : sda_out <= addr_t[5];     
                    7'd9 : scl <= 1'b1;              
                    7'd11: scl <= 1'b0;              
                    7'd12: sda_out <= addr_t[4];     
                    7'd13: scl <= 1'b1;              
                    7'd15: scl <= 1'b0;              
                    7'd16: sda_out <= addr_t[3];     
                    7'd17: scl <= 1'b1;              
                    7'd19: scl <= 1'b0;              
                    7'd20: sda_out <= addr_t[2];     
                    7'd21: scl <= 1'b1;              
                    7'd23: scl <= 1'b0;              
                    7'd24: sda_out <= addr_t[1];     
                    7'd25: scl <= 1'b1;              
                    7'd27: scl <= 1'b0;              
                    7'd28: sda_out <= addr_t[0];     
                    7'd29: scl <= 1'b1;              
                    7'd31: scl <= 1'b0;              
                    7'd32: begin                     
                        sda_dir <= 1'b0;         
                        sda_out <= 1'b1;                    
                    end                              
                    7'd33: scl     <= 1'b1;          
                    7'd34: begin                     //�ӻ�Ӧ��
                        st_done <= 1'b1;     
                        if(sda_in == 1'b1)           //�ߵ�ƽ��ʾδӦ��
                            i2c_ack <= 1'b1;         //����Ӧ���־λ    
                    end   
                    7'd35: begin                     
                        scl <= 1'b0;                 
                        cnt <= 1'b0;                 
                    end                              
                    default :  ;                     
                endcase                              
            end                                      
            st_data_wr: begin                        //д����(8 bit)
                case(cnt)                            
                    7'd0: begin                      
                        sda_out <= data_wr_t[7];     //I2Cд8λ����
                        sda_dir <= 1'b1;             
                    end                              
                    7'd1 : scl <= 1'b1;              
                    7'd3 : scl <= 1'b0;              
                    7'd4 : sda_out <= data_wr_t[6];  
                    7'd5 : scl <= 1'b1;              
                    7'd7 : scl <= 1'b0;              
                    7'd8 : sda_out <= data_wr_t[5];  
                    7'd9 : scl <= 1'b1;              
                    7'd11: scl <= 1'b0;              
                    7'd12: sda_out <= data_wr_t[4];  
                    7'd13: scl <= 1'b1;              
                    7'd15: scl <= 1'b0;              
                    7'd16: sda_out <= data_wr_t[3];  
                    7'd17: scl <= 1'b1;              
                    7'd19: scl <= 1'b0;              
                    7'd20: sda_out <= data_wr_t[2];  
                    7'd21: scl <= 1'b1;              
                    7'd23: scl <= 1'b0;              
                    7'd24: sda_out <= data_wr_t[1];  
                    7'd25: scl <= 1'b1;              
                    7'd27: scl <= 1'b0;              
                    7'd28: sda_out <= data_wr_t[0];  
                    7'd29: scl <= 1'b1;              
                    7'd31: scl <= 1'b0;              
                    7'd32: begin                     
                        sda_dir <= 1'b0;           
                        sda_out <= 1'b1;                              
                    end                              
                    7'd33: scl <= 1'b1;              
                    7'd34: begin                     //�ӻ�Ӧ��
                        st_done <= 1'b1;     
                        if(sda_in == 1'b1)           //�ߵ�ƽ��ʾδӦ��
                            i2c_ack <= 1'b1;         //����Ӧ���־λ    
                    end          
                    7'd35: begin                     
                        scl  <= 1'b0;                
                        cnt  <= 1'b0;                
                    end                              
                    default  :  ;                    
                endcase                              
            end                                      
            st_addr_rd: begin                        //д��ַ�Խ��ж�����
                case(cnt)                            
                    7'd0 : begin                     
                        sda_dir <= 1'b1;             
                        sda_out <= 1'b1;             
                    end                              
                    7'd1 : scl <= 1'b1;              
                    7'd2 : sda_out <= 1'b0;          //���¿�ʼ
                    7'd3 : scl <= 1'b0;              
                    7'd4 : sda_out <= SLAVE_ADDR[6]; //����������ַ
                    7'd5 : scl <= 1'b1;              
                    7'd7 : scl <= 1'b0;              
                    7'd8 : sda_out <= SLAVE_ADDR[5]; 
                    7'd9 : scl <= 1'b1;              
                    7'd11: scl <= 1'b0;              
                    7'd12: sda_out <= SLAVE_ADDR[4]; 
                    7'd13: scl <= 1'b1;              
                    7'd15: scl <= 1'b0;              
                    7'd16: sda_out <= SLAVE_ADDR[3]; 
                    7'd17: scl <= 1'b1;              
                    7'd19: scl <= 1'b0;              
                    7'd20: sda_out <= SLAVE_ADDR[2]; 
                    7'd21: scl <= 1'b1;              
                    7'd23: scl <= 1'b0;              
                    7'd24: sda_out <= SLAVE_ADDR[1]; 
                    7'd25: scl <= 1'b1;              
                    7'd27: scl <= 1'b0;              
                    7'd28: sda_out <= SLAVE_ADDR[0]; 
                    7'd29: scl <= 1'b1;              
                    7'd31: scl <= 1'b0;              
                    7'd32: sda_out <= 1'b1;          //1:��
                    7'd33: scl <= 1'b1;              
                    7'd35: scl <= 1'b0;              
                    7'd36: begin                     
                        sda_dir <= 1'b0;            
                        sda_out <= 1'b1;                    
                    end
                    7'd37: scl     <= 1'b1;
                    7'd38: begin                     //�ӻ�Ӧ��
                        st_done <= 1'b1;     
                        if(sda_in == 1'b1)           //�ߵ�ƽ��ʾδӦ��
                            i2c_ack <= 1'b1;         //����Ӧ���־λ    
                    end   
                    7'd39: begin
                        scl <= 1'b0;
                        cnt <= 1'b0;
                    end
                    default : ;
                endcase
            end
            st_data_rd: begin                        //��ȡ����(8 bit)
                case(cnt)
                    7'd0: sda_dir <= 1'b0;
                    7'd1: begin
                        data_r[7] <= sda_in;
                        scl       <= 1'b1;
                    end
                    7'd3: scl  <= 1'b0;
                    7'd5: begin
                        data_r[6] <= sda_in ;
                        scl       <= 1'b1   ;
                    end
                    7'd7: scl  <= 1'b0;
                    7'd9: begin
                        data_r[5] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd11: scl  <= 1'b0;
                    7'd13: begin
                        data_r[4] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd15: scl  <= 1'b0;
                    7'd17: begin
                        data_r[3] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd19: scl  <= 1'b0;
                    7'd21: begin
                        data_r[2] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd23: scl  <= 1'b0;
                    7'd25: begin
                        data_r[1] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd27: scl  <= 1'b0;
                    7'd29: begin
                        data_r[0] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd31: scl  <= 1'b0;
                    7'd32: begin
                        sda_dir <= 1'b1;             
                        sda_out <= 1'b1;
                    end
                    7'd33: scl     <= 1'b1;
                    7'd34: st_done <= 1'b1;          //��Ӧ��
                    7'd35: begin
                        scl <= 1'b0;
                        cnt <= 1'b0;
                        i2c_data_r <= data_r;
                    end
                    default  :  ;
                endcase
            end
            st_stop: begin                           //����I2C����
                case(cnt)
                    7'd0: begin
                        sda_dir <= 1'b1;             //����I2C
                        sda_out <= 1'b0;
                    end
                    7'd1 : scl     <= 1'b1;
                    7'd3 : sda_out <= 1'b1;
                    7'd15: st_done <= 1'b1;
                    7'd16: begin
                        cnt      <= 1'b0;
                        i2c_done <= 1'b1;            //���ϲ�ģ�鴫��I2C�����ź�
                    end
                    default  : ;
                endcase
            end
        endcase
    end
end

endmodule