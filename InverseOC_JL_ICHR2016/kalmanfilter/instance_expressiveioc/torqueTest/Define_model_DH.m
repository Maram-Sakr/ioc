function twolink = Define_model_DH()

L(1) = Link('d', 0, 'a', 0, 'alpha', -pi/2, 'offset', 0,...
   'm', 0, 'r', [0 0 0], 'I', zeros(3,3), 'qlim', [-pi*2/3 pi/3]);
L(2) = Link('d', 0, 'a', 0, 'alpha', pi/2, 'offset', pi/2, 'm', 1,...
   'r', [0 0 .5], 'I', [1/12*(.5*.5+0.005*0.005) 0 0;...
   0 1/12*(.5*.5 + 0.005*0.005 ) 0; 0 0 1/12*(0.005*0.005 + 0.005*0.005)], 'qlim', [-pi/2 pi/2]);
L(3) = Link('d', 1, 'a', 0, 'alpha', -pi/2, 'offset', 0,...
   'm', 0, 'r', [0 0 0], 'I', zeros(3,3), 'qlim', [0 pi]);
L(4) = Link('d', 0, 'a', 0, 'alpha', pi/2, 'offset', 0,...
   'm', 1,...
   'r', [0 0 .5], 'I', [1/12*(.5*.5+0.005*0.005) 0 0;...
   0 1/12*(.5*.5 + 0.005*0.005 ) 0; 0 0 1/12*(0.005*0.005 + 0.005*0.005)], 'qlim', [0 5*pi/6]);
twolink = SerialLink(L, 'name', 'twolink');
