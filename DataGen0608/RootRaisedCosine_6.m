% function csf = RootRaisedCosine_6(Nb,beta)
% pulse shaping filter: root raised cosine filter with roll-off factor beta
%   length of filter is truncated to -4T to 4T because Nfilt=4
%	Nb = # of samples per symbol; 
%	Nb = Fs / Fb
%	beta = filter roll off factor; use beta = 0.2

function csf = RootRaisedCosine_6(Nb, beta)

Nfilt = 6; %4;  % root raised cosine rolloff filter is 2*Nfilt*Nb+1 samples long
               % 4 give > 30 dB of sidelobe attenuation
               % 6 gives > 37 dB of sidelobe attenuation

T=1;
x=[-Nfilt : 1/Nb : Nfilt];
y = zeros(size(x));

numerator = sin(pi*(1-beta)*x/T)+(4*beta*x/T).*cos(pi*(1+beta)*x/T);
denominator = sqrt(T)*(pi*x/T).*(1-(4*beta*x/T).^2);

excep1 = (x == 0);
y(excep1) = (1-beta+4*beta/pi)/sqrt(T);

excep2 = ((1-(4*beta*x/T).^2) == 0);
y(excep2) = beta*((1+2/pi)*sin(pi/(4*beta))+(1-2/pi)*cos(pi/(4*beta)))/sqrt(2*T);

normal = (denominator ~= 0);
y(normal) = numerator(normal)./denominator(normal);

csf= y/norm(y);

return
