import React, { useEffect, useState, useCallback } from 'react';
import {
  Alert,
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
} from 'react-native';
import InAppPurchase from '@class101/react-native-in-app-purchase';

const PRODUCT_IDS = [
  {id: 'rniap.sample.normal',},
  {
    id: 'rniap.sample.consumable'},
  { id: 'rniap.sample.subscribe'},
];

const App = () => {
  const [products, setProducts] = useState([]);
  
  const handleFetchProducts = (fetchedProducts) => {
    console.log(fetchedProducts);
    setProducts(fetchedProducts);
  };

  const handlePurchase = (purchase) => {
    setTimeout(() => {
      InAppPurchase.finalize(purchase, purchase.productId === 'rniap.sample.consumable').then(() => {
        Alert.alert('In App Purchase', 'Purchase Succeed!');
      });
    });
  };


  useEffect(() => {
    const handleError = (error) => {
      console.log(error);
    };

    InAppPurchase.onFetchProducts(handleFetchProducts);
    InAppPurchase.onPurchase(handlePurchase);
    InAppPurchase.onError(handleError);

    InAppPurchase.configure().then(() => {
      InAppPurchase.fetchProducts(PRODUCT_IDS);
    });

    return () => {
      InAppPurchase.clear();
    };
  }, []);

  const flush = useCallback(() => {
    InAppPurchase.flush().then((purchases) => {
      console.log(purchases);
      purchases.forEach((purchase) => {
        handlePurchase(purchase);
      });
    });
  }, []);

  const renderItem = useCallback((item) => (
    <TouchableOpacity
      key={item.title}
      activeOpacity={0.8}
      onPress={() => InAppPurchase.purchase(item.productId)}
      style={styles.item}
    >
      <Text style={styles.title}>
        {item.title}
      </Text>
      <View style={styles.priceTag}>
        <Text style={styles.priceText}>
          {item.currency} {item.price}
        </Text>
      </View>
    </TouchableOpacity>
  ), []);

  return (
    <View style={styles.container}>
      {products.map(renderItem)}
      <TouchableOpacity
        activeOpacity={0.8}
        onPress={flush}
        style={[styles.item, styles.button]}
      >
        <Text style={styles.text}>
          Flush uncompleted purchases
        </Text>
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    backgroundColor: '#FFF',
  },
  item: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 24,
    marginHorizontal: 24,
    paddingVertical: 20,
    paddingHorizontal: 16,
    backgroundColor: '#F2F4F9',
  },
  title: {
    fontSize: 16,
    color: '#191919',
  },
  priceTag: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 2,
    backgroundColor: '#2D2D2D'
  },
  priceText: {
    fontSize: 12,
    color: '#FAFAFA',
  },
  button: {
    marginTop: 16,
    marginBottom: 0,
    justifyContent: 'center',
    backgroundColor: '#2D2D2D',
    borderRadius: 32,
  },
  text: {
    fontSize: 16,
    color: '#FAFAFA',
  },
});

export default App;