import { h, render, View, Text } from '../../../js/react-light.js';

// Text 컴포넌트 도입 + 외곽 column flex(padding/gap) + 상단 Text "0" 자리 +
// 하단 파란 placeholder. 값은 하드코딩 (state 연결은 다음 commit).
render(
  <View flex={1} padding={16} gap={16}>
    <View flexDirection="row" justifyContent="center" alignItems="center">
      <Text fontSize={48} color="#000000">0</Text>
    </View>
    <View flex={1} backgroundColor="#0066ff" />
  </View>
);
