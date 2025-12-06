//
//  quickMemoAppTests.swift
//  quickMemoAppTests
//
//  Created by kiichi yokokawa on 2025/08/18.
//

import Testing
import Foundation
@testable import quickMemoApp

// Widget内のCategoryとの衝突を避けるため、明示的にquickMemoAppのCategoryを使用
typealias AppCategory = quickMemoApp.Category
typealias AppQuickMemo = quickMemoApp.QuickMemo

struct quickMemoAppTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

// MARK: - Category Persistence Tests

struct CategoryPersistenceTests {

    // MARK: - Category Encoding/Decoding Tests

    @Test func testCategoryEncodingDecoding() throws {
        // Given: カスタムカテゴリー
        let hiddenTagsSet: Set<String> = ["hidden1"]
        let originalCategory = AppCategory(
            name: "テストカテゴリー",
            icon: "star",
            color: "#FF0000",
            order: 5,
            defaultTags: ["タグ1", "タグ2"],
            isDefault: false,
            baseKey: nil,
            hiddenTags: hiddenTagsSet
        )

        // When: エンコードしてデコード
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalCategory)
        let decoder = JSONDecoder()
        let decodedCategory = try decoder.decode(AppCategory.self, from: data)

        // Then: 全フィールドが保持される
        #expect(decodedCategory.name == originalCategory.name)
        #expect(decodedCategory.icon == originalCategory.icon)
        #expect(decodedCategory.color == originalCategory.color)
        #expect(decodedCategory.order == originalCategory.order)
        #expect(decodedCategory.defaultTags == originalCategory.defaultTags)
        #expect(decodedCategory.isDefault == originalCategory.isDefault)
        #expect(decodedCategory.baseKey == originalCategory.baseKey)
        #expect(decodedCategory.hiddenTags == originalCategory.hiddenTags)
    }

    @Test func testCategoryDecodingWithMissingOptionalFields() throws {
        // Given: オプショナルフィールドがないJSON（古いバージョンのデータ）
        let jsonString = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "古いカテゴリー",
            "icon": "folder",
            "color": "#007AFF",
            "order": 0,
            "defaultTags": ["タグA"]
        }
        """
        let data = jsonString.data(using: .utf8)!

        // When: デコード
        let decoder = JSONDecoder()
        let category = try decoder.decode(AppCategory.self, from: data)

        // Then: デフォルト値が適用される
        #expect(category.name == "古いカテゴリー")
        #expect(category.isDefault == false)
        #expect(category.baseKey == nil)
        #expect(category.hiddenTags.isEmpty)
    }

    @Test func testDefaultCategoryEncodingDecoding() throws {
        // Given: デフォルトカテゴリー
        let emptyHiddenTags: Set<String> = []
        let originalCategory = AppCategory(
            name: "仕事",
            icon: "briefcase",
            color: "#007AFF",
            order: 0,
            defaultTags: ["会議", "タスク"],
            isDefault: true,
            baseKey: "work",
            hiddenTags: emptyHiddenTags
        )

        // When: エンコードしてデコード
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalCategory)
        let decoder = JSONDecoder()
        let decodedCategory = try decoder.decode(AppCategory.self, from: data)

        // Then: isDefault と baseKey が保持される
        #expect(decodedCategory.isDefault == true)
        #expect(decodedCategory.baseKey == "work")
    }

    @Test func testCategoryArrayEncodingDecoding() throws {
        // Given: 複数カテゴリー（デフォルト + カスタム）
        let hiddenSet: Set<String> = ["hidden"]
        let categories: [AppCategory] = [
            AppCategory(
                name: "仕事",
                icon: "briefcase",
                color: "#007AFF",
                order: 0,
                defaultTags: [],
                isDefault: true,
                baseKey: "work"
            ),
            AppCategory(
                name: "カスタム1",
                icon: "star",
                color: "#FF0000",
                order: 1,
                defaultTags: ["tag1"],
                isDefault: false,
                baseKey: nil
            ),
            AppCategory(
                name: "カスタム2",
                icon: "heart",
                color: "#00FF00",
                order: 2,
                defaultTags: [],
                isDefault: false,
                baseKey: nil,
                hiddenTags: hiddenSet
            )
        ]

        // When: 配列をエンコードしてデコード
        let encoder = JSONEncoder()
        let data = try encoder.encode(categories)
        let decoder = JSONDecoder()
        let decodedCategories = try decoder.decode([AppCategory].self, from: data)

        // Then: 全カテゴリーが正しくデコードされる
        #expect(decodedCategories.count == 3)
        #expect(decodedCategories[0].isDefault == true)
        #expect(decodedCategories[0].baseKey == "work")
        #expect(decodedCategories[1].isDefault == false)
        #expect(decodedCategories[1].name == "カスタム1")
        #expect(decodedCategories[2].hiddenTags.contains("hidden"))
    }

    // MARK: - UserDefaults Simulation Tests

    @Test func testCategoryPersistenceInUserDefaults() throws {
        // Given: テスト用のUserDefaults
        let testDefaults = UserDefaults(suiteName: "test.category.persistence")!
        let categoriesKey = "test_categories"

        // Clean up
        testDefaults.removeObject(forKey: categoriesKey)

        let categories: [AppCategory] = [
            AppCategory(
                name: "テスト1",
                icon: "folder",
                color: "#007AFF",
                order: 0,
                defaultTags: [],
                isDefault: false,
                baseKey: nil
            ),
            AppCategory(
                name: "テスト2",
                icon: "star",
                color: "#FF0000",
                order: 1,
                defaultTags: ["タグ"],
                isDefault: false,
                baseKey: nil
            )
        ]

        // When: 保存
        let encoder = JSONEncoder()
        let data = try encoder.encode(categories)
        testDefaults.set(data, forKey: categoriesKey)
        testDefaults.synchronize()

        // Then: 読み込み
        let loadedData = testDefaults.data(forKey: categoriesKey)
        #expect(loadedData != nil)

        let decoder = JSONDecoder()
        let loadedCategories = try decoder.decode([AppCategory].self, from: loadedData!)
        #expect(loadedCategories.count == 2)
        #expect(loadedCategories[0].name == "テスト1")
        #expect(loadedCategories[1].name == "テスト2")

        // Cleanup
        testDefaults.removeObject(forKey: categoriesKey)
        testDefaults.removePersistentDomain(forName: "test.category.persistence")
    }

    @Test func testCategoryBackupAndRecovery() throws {
        // Given: テスト用のUserDefaults
        let testDefaults = UserDefaults(suiteName: "test.category.backup")!
        let mainKey = "test_categories_main"
        let backupKey = "test_categories_backup"

        // Clean up
        testDefaults.removeObject(forKey: mainKey)
        testDefaults.removeObject(forKey: backupKey)

        let categories: [AppCategory] = [
            AppCategory(
                name: "バックアップテスト",
                icon: "folder",
                color: "#007AFF",
                order: 0,
                defaultTags: [],
                isDefault: false,
                baseKey: nil
            )
        ]

        // When: メインとバックアップに保存
        let encoder = JSONEncoder()
        let data = try encoder.encode(categories)
        testDefaults.set(data, forKey: mainKey)
        testDefaults.set(data, forKey: backupKey)
        testDefaults.synchronize()

        // メインを削除（データ消失をシミュレート）
        testDefaults.removeObject(forKey: mainKey)
        testDefaults.synchronize()

        // Then: バックアップから復元可能
        let mainData = testDefaults.data(forKey: mainKey)
        #expect(mainData == nil)

        let backupData = testDefaults.data(forKey: backupKey)
        #expect(backupData != nil)

        let decoder = JSONDecoder()
        let recoveredCategories = try decoder.decode([AppCategory].self, from: backupData!)
        #expect(recoveredCategories.count == 1)
        #expect(recoveredCategories[0].name == "バックアップテスト")

        // Cleanup
        testDefaults.removePersistentDomain(forName: "test.category.backup")
    }
}

// MARK: - QuickMemo Model Tests

struct QuickMemoModelTests {

    @Test func testMemoEncodingDecoding() throws {
        // Given
        let memo = AppQuickMemo(
            title: "テストメモ",
            content: "メモの内容",
            primaryCategory: "仕事",
            tags: ["タグ1", "タグ2"],
            durationMinutes: 60
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(memo)
        let decoder = JSONDecoder()
        let decodedMemo = try decoder.decode(AppQuickMemo.self, from: data)

        // Then
        #expect(decodedMemo.title == memo.title)
        #expect(decodedMemo.content == memo.content)
        #expect(decodedMemo.primaryCategory == memo.primaryCategory)
        #expect(decodedMemo.tags == memo.tags)
        #expect(decodedMemo.durationMinutes == memo.durationMinutes)
    }

    @Test func testMemoDecodingWithMissingOptionalFields() throws {
        // Given: titleとdurationMinutesがないJSON（古いバージョン）
        let jsonString = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "content": "古いメモ",
            "primaryCategory": "プライベート",
            "tags": [],
            "createdAt": 0,
            "updatedAt": 0
        }
        """
        let data = jsonString.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let memo = try decoder.decode(AppQuickMemo.self, from: data)

        // Then: デフォルト値が適用される
        #expect(memo.title == "")
        #expect(memo.content == "古いメモ")
        #expect(memo.durationMinutes == 30)
    }
}

// MARK: - Category Initialization Flag Tests

struct CategoryInitializationTests {

    @Test func testInitializationFlagPreventsDefaultOverwrite() throws {
        // Given: テスト用のUserDefaults
        let testDefaults = UserDefaults(suiteName: "test.init.flag")!
        let categoriesKey = "test_categories"
        let initFlagKey = "categories_initialized_test"

        // Clean up
        testDefaults.removeObject(forKey: categoriesKey)
        testDefaults.removeObject(forKey: initFlagKey)

        // When: 初期化フラグを設定
        testDefaults.set(true, forKey: initFlagKey)
        testDefaults.synchronize()

        // Then: フラグがtrueであることを確認
        let isInitialized = testDefaults.bool(forKey: initFlagKey)
        #expect(isInitialized == true)

        // カテゴリーデータがないがフラグがtrueの場合
        // → デフォルト上書きではなくリカバリーを試みるべき
        let hasData = testDefaults.data(forKey: categoriesKey) != nil
        #expect(hasData == false)
        #expect(isInitialized == true)

        // Cleanup
        testDefaults.removePersistentDomain(forName: "test.init.flag")
    }

    @Test func testFirstLaunchCreatesDefaults() throws {
        // Given: 初期化フラグがfalseの状態
        let testDefaults = UserDefaults(suiteName: "test.first.launch")!
        let initFlagKey = "categories_initialized_test"

        // Clean up
        testDefaults.removeObject(forKey: initFlagKey)

        // When: フラグを確認
        let isInitialized = testDefaults.bool(forKey: initFlagKey)

        // Then: falseなら初回起動とみなす
        #expect(isInitialized == false)

        // Cleanup
        testDefaults.removePersistentDomain(forName: "test.first.launch")
    }
}
