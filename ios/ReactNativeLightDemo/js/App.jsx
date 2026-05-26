import {
  h,
  render,
  useState,
  View,
  Text,
  ScrollView,
  Pressable,
} from '../../../js/react-light.js';

function Button({ label, color, onPress }) {
  return (
    <Pressable
      backgroundColor={color}
      width={60}
      height={50}
      justifyContent="center"
      alignItems="center"
      onPress={onPress}
    >
      <Text fontSize={28} color="#ffffff">
        {label}
      </Text>
    </Pressable>
  );
}

function App() {
  const [count, setCount] = useState(0);
  const [history, setHistory] = useState([0]);

  // 한 동작에서 useState 두 개 동시 갱신 — count + history 둘 다.
  const change = (delta) => {
    const next = count + delta;
    setCount(next);
    setHistory([...history, next]);
  };

  return (
    <View flex={1} padding={16} gap={16}>
      <View
        flexDirection="row"
        gap={16}
        justifyContent="center"
        alignItems="center"
      >
        <Button color="#ff3333" label="-" onPress={() => change(-1)} />
        <Text
          width={80}
          textAlign="center"
          fontSize={48}
          color="#000000"
        >
          {count}
        </Text>
        <Button color="#0066ff" label="+" onPress={() => change(1)} />
      </View>

      <ScrollView flex={1} backgroundColor="#f5f5f5" padding={16} gap={4}>
        {history.map((value, i) => (
          <Text key={i} fontSize={18} color="#222222">
            {value}
          </Text>
        ))}
      </ScrollView>
    </View>
  );
}

render(<App />);
