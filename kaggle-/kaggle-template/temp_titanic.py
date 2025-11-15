#!/usr/bin/env python
# coding: utf-8

# In[ ]:


import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import cross_val_score
import warnings
import lightgbm as lgb
warnings.filterwarnings('ignore')

# データ読み込み
train_data = pd.read_csv('../input/titanic/train.csv')
test_data = pd.read_csv('../input/titanic/test.csv')

print("Train data shape:", train_data.shape)
print("Test data shape:", test_data.shape)
print("\nTrain data info:")
train_data.info()


# In[9]:


# 基本的な統計を確認
print("生存率:", train_data['Survived'].mean())
print("\nクラス別生存率:")
print(train_data.groupby('Pclass')['Survived'].mean())
print("\n性別生存率:")
print(train_data.groupby('Sex')['Survived'].mean())
print("\n欠損値の確認:")
print(train_data.isnull().sum())


# In[10]:


# 特徴量エンジニアリング関数
def feature_engineering(df):
    """特徴量を作成・処理する"""
    df = df.copy()

    # Age の欠損値を中央値で埋める
    df['Age'] = df['Age'].fillna(df['Age'].median())

    # Embarked の欠損値を最頻値で埋める
    df['Embarked'] = df['Embarked'].fillna(df['Embarked'].mode()[0])

    # Fare の欠損値を中央値で埋める
    df['Fare'] = df['Fare'].fillna(df['Fare'].median())

    # 家族の人数
    df['FamilySize'] = df['SibSp'] + df['Parch'] + 1

    # 一人かどうか
    df['IsAlone'] = (df['FamilySize'] == 1).astype(int)

    # Sex を数値化
    df['Sex'] = df['Sex'].map({'male': 0, 'female': 1})

    # Embarked を数値化
    df['Embarked'] = df['Embarked'].map({'S': 0, 'C': 1, 'Q': 2})

    # Age を年齢帯に分ける
    df['AgeGroup'] = pd.cut(df['Age'], bins=[0, 12, 18, 35, 60, 100], labels=[0, 1, 2, 3, 4])
    df['AgeGroup'] = df['AgeGroup'].astype(int)

    # Fare を運賃帯に分ける
    df['FareGroup'] = pd.qcut(df['Fare'], q=4, labels=[0, 1, 2, 3], duplicates='drop')
    df['FareGroup'] = df['FareGroup'].astype(int)

    return df

# 特徴量エンジニアリング適用
train_processed = feature_engineering(train_data)
test_processed = feature_engineering(test_data)

print("特徴量エンジニアリング完了")
print("Train shape:", train_processed.shape)
print("Test shape:", test_processed.shape)


# In[11]:


# 使用する特徴量を選択
feature_columns = ['Pclass', 'Sex', 'Age', 'SibSp', 'Parch', 'Fare', 'Embarked', 
                   'FamilySize', 'IsAlone', 'AgeGroup', 'FareGroup']

X_train = train_processed[feature_columns]
y_train = train_processed['Survived']
X_test = test_processed[feature_columns]

print("学習データ:", X_train.shape)
print("テストデータ:", X_test.shape)
print("\n特徴量一覧:")
print(feature_columns)


# In[12]:


# モデル構築と訓練
model = RandomForestClassifier(
    n_estimators=100,
    max_depth=5,
    min_samples_split=10,
    min_samples_leaf=4,
    random_state=42
)

# クロスバリデーションでスコアを確認
cv_scores = cross_val_score(model, X_train, y_train, cv=5, scoring='accuracy')
print(f"Cross-Validation Accuracy: {cv_scores.mean():.4f} (+/- {cv_scores.std():.4f})")

# 全データで訓練
model.fit(X_train, y_train)
print("\nモデル訓練完了！")

# 特徴量の重要度
feature_importance = pd.DataFrame({
    'feature': feature_columns,
    'importance': model.feature_importances_
}).sort_values('importance', ascending=False)

print("\n特徴量重要度:")
print(feature_importance)


# In[13]:


# テストデータで予測
predictions = model.predict(X_test)

print(f"予測完了！")
print(f"予測数: {len(predictions)}")
print(f"生存予測: {predictions.sum()}")
print(f"死亡予測: {len(predictions) - predictions.sum()}")
print(f"生存率: {predictions.mean():.2%}")


# In[14]:


# Submission ファイルを作成
submission = pd.DataFrame({
    'PassengerId': test_data['PassengerId'],
    'Survived': predictions
})

# outputフォルダに保存
output_path = '../output/submission.csv'
submission.to_csv(output_path, index=False)

print(f"Submission ファイルを作成しました: {output_path}")
print(f"\nSubmission ファイルの内容（先頭5行）:")
print(submission.head())
print(f"\nファイル形式確認:")
print(f"- 行数: {len(submission)}")
print(f"- 列: {list(submission.columns)}")
print(f"- Survived の値: {sorted(submission['Survived'].unique())}")

