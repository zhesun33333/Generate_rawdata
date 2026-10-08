function [Passband_Signal, OFDM_Symbol, symbol_code] = OFDM_Signal_Creator(Tramsmit_Bit,Modulation_Order,Frequency_of_Sample,Frequency_of_Center,Bandwidth,CP_Factor)

    bit_matrix = reshape(Tramsmit_Bit, Modulation_Order, []).';
    symbol_code = bit_matrix * (2.^(Modulation_Order - 1:-1:0)).';
    OFDM_Symbol = pskmod(bit_matrix.', 2^Modulation_Order, 'InputType','bit').';
    [M,~] = size(OFDM_Symbol);
    
    Time_Duration = M/Bandwidth; 
    
    Transmit_Signal = ifft([OFDM_Symbol(1:M/2); zeros(Time_Duration*Frequency_of_Sample-M, 1); OFDM_Symbol(M/2+1:end)]);
    % Add CP 
    Transmit_Signal = [Transmit_Signal(end-CP_Factor*Time_Duration*Frequency_of_Sample+1:end); Transmit_Signal];
    Passband_Signal = real(Transmit_Signal.*exp(1j*2*pi*Frequency_of_Center*(1:Frequency_of_Sample*Time_Duration*(1+CP_Factor))'/Frequency_of_Sample));

end
