function [Z_total, I_total, V_R, V_L, V_C] = analyzeACCircuit(R, L, C, frequency, Vsource)
% Analyze a series RLC circuit across a frequency sweep.
%
% Computes complex impedance, current, and voltage drops across each
% component at every frequency in the input vector. All outputs are
% complex phasors representing magnitude and phase of the AC quantities.
%
% Accepts a vector of frequencies for impedance spectroscopy / Bode plot
% analysis — the standard engineering workflow for characterizing filters,
% crossover networks, and EMI suppression circuits.
%
% Without wire encoding, complex numbers cannot be represented in JSON.
% The outputs of this function are inherently complex-valued and have no
% plain JSON representation.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        R (1,1) double           % Resistance (Ohms)
        L (1,1) double           % Inductance (Henries)
        C (1,1) double           % Capacitance (Farads)
        frequency (:,1) double   % Frequency vector (Hz)
        Vsource (1,1) double     % Source voltage amplitude (Volts)
    end
    arguments(Output)
        Z_total (:,1) double     % Total complex impedance at each frequency (Ohms)
        I_total (:,1) double     % Complex current phasor at each frequency (Amps)
        V_R (:,1) double         % Voltage across resistor at each frequency (Volts)
        V_L (:,1) double         % Voltage across inductor at each frequency (Volts)
        V_C (:,1) double         % Voltage across capacitor at each frequency (Volts)
    end

    omega = 2 * pi * frequency;

    Z_R = R;
    Z_L = 1j * omega * L;
    Z_C = 1 ./ (1j * omega * C);

    Z_total = Z_R + Z_L + Z_C;
    I_total = Vsource ./ Z_total;

    V_R = I_total * Z_R;
    V_L = I_total .* Z_L;
    V_C = I_total .* Z_C;

end
