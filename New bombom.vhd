--UNIVERSIDADE ESTADUAL DO SUDOESTE DA BAHIA - UESB
--TÓPICOS DE INFORMÁTICA APLICADA - TIA/ADM
--PROF. MARCO A. D. RAMOS
--Discentes: Eduardo Ribeiro Fontes e Pedro Cândido
--DATA: 25 de setembro de 2026
--Especificação: Máquina de Vender Salgados (versão para a placa DE1)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bombom01 is
   port (
      clk                : in  std_logic;   -- CLOCK_50 (50 MHz)

      -- botões KEY da DE1: ativos em nível baixo ('0' = pressionado)
      reset_n            : in  std_logic;   -- KEY0
      moeda_inserida_n   : in  std_logic;   -- KEY1
      confirma_selecao_n : in  std_logic;   -- KEY2
      desiste_n          : in  std_logic;   -- KEY3

      -- chaves SW
      moeda_valor        : in  std_logic_vector(1 downto 0);  -- SW9..SW8: 00=inválida, 01=0,25, 10=0,50, 11=1,00
      sel_produto        : in  std_logic_vector(2 downto 0);  -- SW2..SW0
      estoque            : in  std_logic_vector(4 downto 0);  -- SW7..SW3: '1' = tem estoque

      -- LEDs
      moedas_aceitas         : out std_logic_vector(2 downto 0);  -- LEDG7..LEDG5
      aviso_sem_estoque      : out std_logic;                     -- LEDR0
      moeda_invalida         : out std_logic;                     -- LEDR1 (estendido ~1 s)
      libera_salgado         : out std_logic;                     -- LEDG0 (estendido ~1 s)
      libera_troco           : out std_logic;                     -- LEDG1 (estendido ~1 s)
      libera_todas_as_moedas : out std_logic;                     -- LEDG2 (estendido ~1 s)

      -- displays de 7 segmentos (ativos em nível baixo)
      display_reais      : out std_logic_vector(6 downto 0);  -- HEX1: saldo, reais
      display_decimo     : out std_logic_vector(6 downto 0);  -- HEX0: saldo, primeiro decimal
      troco_reais        : out std_logic_vector(6 downto 0);  -- HEX3: troco, reais
      troco_decimo       : out std_logic_vector(6 downto 0)   -- HEX2: troco, primeiro decimal
   );
end bombom01;

architecture arc_bombons of bombom01 is

   constant ACEITA : std_logic_vector(2 downto 0) := "111";

   -- 50.000.000 ciclos de 20 ns = 1 segundo
   constant TEMPO_LED : integer := 50000000;

   type estado_t is (AGUARDANDO, AVISO, RECEBENDO, LIBERANDO);
   signal estado_atual : estado_t := AGUARDANDO;

   signal preco_atual : integer range 0 to 999 := 0;  -- preço do código nas chaves
   signal preco_trava : integer range 0 to 999 := 0;  -- preço travado ao confirmar
   signal saldo_atual : integer range 0 to 999 := 0;
   signal troco_atual : integer range 0 to 999 := 0;

   -- sincronizador + detector de borda dos botões (ordem: desiste, confirma, moeda)
   signal b1, b2, b3 : std_logic_vector(2 downto 0) := (others => '0');
   signal moeda_p, confirma_p, desiste_p : std_logic;

   -- pulsos de 1 ciclo gerados pela FSM (antes do estendedor de LED)
   signal salgado_p, troco_p, todas_p, invalida_p : std_logic := '0';

   function seg7(digito : integer range 0 to 9) return std_logic_vector is
   begin
      case digito is
         when 0 => return "1000000";
         when 1 => return "1111001";
         when 2 => return "0100100";
         when 3 => return "0110000";
         when 4 => return "0011001";
         when 5 => return "0010010";
         when 6 => return "0000010";
         when 7 => return "1111000";
         when 8 => return "0000000";
         when 9 => return "0010000";
      end case;
   end function;

begin

   moedas_aceitas <= ACEITA;

   ---------------------------------------------------------------------
   -- tabela de produtos: código de 3 bits -> preço (em centavos)
   ---------------------------------------------------------------------
   process (sel_produto)
   begin
      case sel_produto is
         when "000"  => preco_atual <= 250;  -- Batata frita grande: 2,50
         when "001"  => preco_atual <= 150;  -- Batata frita média:  1,50
         when "010"  => preco_atual <= 75;   -- Batata frita pequena: 0,75
         when "011"  => preco_atual <= 350;  -- Tortilha grande:     3,50
         when "100"  => preco_atual <= 200;  -- Tortilha pequena:    2,00
         when others => preco_atual <= 0;    -- códigos inexistentes
      end case;
   end process;

   ---------------------------------------------------------------------
   -- displays
   ---------------------------------------------------------------------
   display_reais  <= seg7(saldo_atual / 100);
   display_decimo <= seg7((saldo_atual mod 100) / 10);
   troco_reais    <= seg7(troco_atual / 100);
   troco_decimo   <= seg7((troco_atual mod 100) / 10);

   ---------------------------------------------------------------------
   -- botões: sincroniza (2 flip-flops) e gera 1 pulso por aperto
   ---------------------------------------------------------------------
   process (clk)
   begin
      if (clk'event and clk = '1') then
         b1 <= not (desiste_n & confirma_selecao_n & moeda_inserida_n);
         b2 <= b1;
         b3 <= b2;
      end if;
   end process;

   moeda_p    <= b2(0) and not b3(0);
   confirma_p <= b2(1) and not b3(1);
   desiste_p  <= b2(2) and not b3(2);

   ---------------------------------------------------------------------
   -- máquina de estados
   ---------------------------------------------------------------------
   process (clk, reset_n)
      variable saldo_tmp   : integer range 0 to 999;
      variable tem_estoque : std_logic;
   begin
      if (reset_n = '0') then
         estado_atual      <= AGUARDANDO;
         saldo_atual       <= 0;
         troco_atual       <= 0;
         preco_trava       <= 0;
         salgado_p         <= '0';
         troco_p           <= '0';
         todas_p           <= '0';
         invalida_p        <= '0';
         aviso_sem_estoque <= '0';

      elsif (clk'event and clk = '1') then

         salgado_p         <= '0';
         troco_p           <= '0';
         todas_p           <= '0';
         invalida_p        <= '0';
         aviso_sem_estoque <= '0';

         case estado_atual is

            when AGUARDANDO =>
               if (confirma_p = '1') then
                  if (to_integer(unsigned(sel_produto)) <= 4) then
                     tem_estoque := estoque(to_integer(unsigned(sel_produto)));
                  else
                     tem_estoque := '0';   -- código inválido: trata como sem estoque
                  end if;

                  if (tem_estoque = '1') then
                     preco_trava  <= preco_atual;  -- trava o preço escolhido
                     troco_atual  <= 0;            -- limpa o troco da compra anterior
                     estado_atual <= RECEBENDO;
                  else
                     estado_atual <= AVISO;
                  end if;
               end if;

            when AVISO =>
               aviso_sem_estoque <= '1';
               if (confirma_p = '1') then
                  estado_atual <= AGUARDANDO;
               end if;

            when RECEBENDO =>
               saldo_tmp := saldo_atual;

               if (desiste_p = '1') then
                  todas_p      <= '1';
                  troco_atual  <= saldo_tmp;   -- devolve tudo
                  saldo_tmp    := 0;
                  estado_atual <= AGUARDANDO;

               elsif (moeda_p = '1') then
                  case moeda_valor is
                     when "01"   => saldo_tmp := saldo_tmp + 25;
                     when "10"   => saldo_tmp := saldo_tmp + 50;
                     when "11"   => saldo_tmp := saldo_tmp + 100;
                     when others => invalida_p <= '1';  -- moeda inválida, não soma
                  end case;

                  if (saldo_tmp >= preco_trava) then
                     estado_atual <= LIBERANDO;
                  end if;
               end if;

               saldo_atual <= saldo_tmp;

            when LIBERANDO =>
               salgado_p <= '1';
               if (saldo_atual > preco_trava) then
                  troco_p     <= '1';
                  troco_atual <= saldo_atual - preco_trava;
               else
                  troco_atual <= 0;
               end if;
               saldo_atual  <= 0;
               estado_atual <= AGUARDANDO;

         end case;
      end if;
   end process;

   ---------------------------------------------------------------------
   -- estendedor de pulso: mantém o LED aceso ~1 s para dar para enxergar
   ---------------------------------------------------------------------
   process (clk)
      type cont_t is array (0 to 3) of integer range 0 to TEMPO_LED;
      variable c : cont_t := (others => 0);
      variable gatilho : std_logic_vector(0 to 3);
   begin
      if (clk'event and clk = '1') then
         gatilho := salgado_p & troco_p & todas_p & invalida_p;

         for i in 0 to 3 loop
            if (gatilho(i) = '1') then
               c(i) := TEMPO_LED;
            elsif (c(i) > 0) then
               c(i) := c(i) - 1;
            end if;
         end loop;

         if (c(0) > 0) then libera_salgado         <= '1'; else libera_salgado         <= '0'; end if;
         if (c(1) > 0) then libera_troco           <= '1'; else libera_troco           <= '0'; end if;
         if (c(2) > 0) then libera_todas_as_moedas <= '1'; else libera_todas_as_moedas <= '0'; end if;
         if (c(3) > 0) then moeda_invalida         <= '1'; else moeda_invalida         <= '0'; end if;
      end if;
   end process;

end arc_bombons;
