function configs = get_ship_configs()
%GET_SHIP_CONFIGS 生成五类舰船的仿真参数配置。
%
% 说明：
%   modRange 表示调制系数总范围。
%   mainModMin 表示轴频和叶频处调制系数的下限。
%   其他调制频率处的调制系数会被强制小于轴频/叶频处。

% 1. 水下目标
configs.underwater_target.displayNameZh = '水下目标';
configs.underwater_target.bladeChoices = [5, 7];
configs.underwater_target.modRange = [0.01, 0.08];
configs.underwater_target.mainModMin = 0.06;
configs.underwater_target.SPL1KRange = [103, 130];
configs.underwater_target.lineFreqRange = [10, 200];
configs.underwater_target.lineSNRRange = [6, 10];
configs.underwater_target.depthRange = [20, 300];
configs.underwater_target.distanceRangeKm = [0.2, 3.0];
configs.underwater_target.shaftFreqRange = [1.5, 18];

% 2. 小渔船
configs.fishing_boat.displayNameZh = '小渔船';
configs.fishing_boat.bladeChoices = [3, 4, 5];
configs.fishing_boat.modRange = [0.10, 0.20];
configs.fishing_boat.mainModMin = 0.15;
configs.fishing_boat.SPL1KRange = [118, 136];
configs.fishing_boat.lineFreqRange = [10, 1000];
configs.fishing_boat.lineSNRRange = [6, 10];
configs.fishing_boat.depthRange = [5, 10];
configs.fishing_boat.distanceRangeKm = [0.2, 3.0];
configs.fishing_boat.shaftFreqRange = [3, 35];

% 3. 货船
configs.cargo_ship.displayNameZh = '货船';
configs.cargo_ship.bladeChoices = [3, 4, 5];
configs.cargo_ship.modRange = [0.10, 0.20];
configs.cargo_ship.mainModMin = 0.15;
configs.cargo_ship.SPL1KRange = [124, 142];
configs.cargo_ship.lineFreqRange = [10, 1000];
configs.cargo_ship.lineSNRRange = [6, 10];
configs.cargo_ship.depthRange = [5, 10];
configs.cargo_ship.distanceRangeKm = [0.2, 3.0];
configs.cargo_ship.shaftFreqRange = [2, 25];

% 4. 游轮
configs.cruise_ship.displayNameZh = '游轮';
configs.cruise_ship.bladeChoices = [3, 4, 5];
configs.cruise_ship.modRange = [0.10, 0.20];
configs.cruise_ship.mainModMin = 0.15;
configs.cruise_ship.SPL1KRange = [120, 148];
configs.cruise_ship.lineFreqRange = [10, 1000];
configs.cruise_ship.lineSNRRange = [6, 10];
configs.cruise_ship.depthRange = [5, 10];
configs.cruise_ship.distanceRangeKm = [0.2, 3.0];
configs.cruise_ship.shaftFreqRange = [2, 22];

% 5. 军舰
configs.warship.displayNameZh = '军舰';
configs.warship.bladeChoices = [3, 4, 5];
configs.warship.modRange = [0.04, 0.12];
configs.warship.mainModMin = 0.10;
configs.warship.SPL1KRange = [124, 148];
configs.warship.lineFreqRange = [10, 1000];
configs.warship.lineSNRRange = [6, 10];
configs.warship.depthRange = [5, 10];
configs.warship.distanceRangeKm = [0.2, 3.0];
configs.warship.shaftFreqRange = [2, 28];

end
