//
//  WEPhotoGroupDetailController.m
//  ImagePicker
//
//  Created by Turbo on 2017/7/24.
//  Copyright © 2017年 Turbo. All rights reserved.
//

#import "WEPhotoGroupDetailController.h"

static NSString * const reuseIdentifier = @"WEPhotoCell";

@interface WEPhotoGroupDetailController ()

/* 选中图片数组 */
@property(nonatomic, strong) NSMutableArray *selectedPhotos;
/* 已选图片数量 */
@property(nonatomic, assign) NSInteger photosCount;
/* 选中image数组 */
@property(nonatomic, strong) NSMutableArray *imageArray;
/* 展示已选图片数量 */
@property (nonatomic, strong) UILabel *photoCountLab;
/* 完成按钮 */
@property (nonatomic, strong) UIButton *completeBtn;

@end

@implementation WEPhotoGroupDetailController

- (instancetype)init {
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat padding = WEImagePicker_Item_Padding;
    layout.sectionInset = UIEdgeInsetsMake(padding, padding, padding, padding);
    layout.minimumLineSpacing = padding;
    layout.minimumInteritemSpacing = CGFLOAT_MIN;
    
    return [super initWithCollectionViewLayout:layout];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = self.groupName;
    
    self.collectionView.backgroundColor = [UIColor whiteColor];
    self.collectionView.allowsMultipleSelection = YES;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:[WEPhotoCell class] forCellWithReuseIdentifier:reuseIdentifier];

    CGRect frame = self.collectionView.frame;
    frame.size.height = WEScreenHeight - WETabBarHeight;
    self.collectionView.frame = frame;
    
    // 取消
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(cancelBtnClick:)];
    
    // 底部
    UIView *bottomView = [[UIView alloc]initWithFrame:CGRectMake(0, WEScreenHeight - WETabBarHeight, WEScreenWidth, WETabBarHeight)];
    [bottomView addSubview:self.completeBtn];
    [bottomView addSubview:self.photoCountLab];
    bottomView.backgroundColor = WERGBCOLOR(52, 156, 251);
    [self.view addSubview:bottomView];
}

// 取消
- (void)cancelBtnClick:(UIBarButtonItem *)cancelBarButtonItem {
    cancelBarButtonItem.enabled = NO;
    [self dismissViewControllerAnimated:YES completion:nil];
}

// 从PHAsset中获取image
- (void)imageWithAsset:(PHAsset *)asset completion:(WEImagePicker_imageBlock)completion {
    PHImageRequestOptions *imageOptions = [[PHImageRequestOptions alloc] init];
    imageOptions.synchronous = YES;
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(asset.pixelWidth, asset.pixelHeight) contentMode:PHImageContentModeAspectFill options:imageOptions resultHandler:^(UIImage *result, NSDictionary *info) {
        completion(result);
    }];
}

- (void)setPhotoALAssets:(NSArray *)photoALAssets {
    _photoALAssets = photoALAssets;
    if (photoALAssets.count > 0)
        self.photosCount = photoALAssets.count - 1;
    [self.collectionView reloadData];
}

- (NSMutableArray *)selectedPhotos {
    if (!_selectedPhotos)
        _selectedPhotos = [NSMutableArray array];
    return _selectedPhotos;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.photoALAssets.count;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat padding = WEImagePicker_Item_Padding;
    CGFloat columns = WEImagePicker_Item_Columns;
    CGFloat width = (CGRectGetWidth(self.view.frame) - 2 *padding  - padding * (columns - 1))/columns;
    return CGSizeMake(width, width);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    WEPhotoCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    WEPhotoALAssets *photoALAssets = self.photoALAssets[self.photosCount - indexPath.row];
    cell.photoALAsset = photoALAssets;
    
    return cell;
}


#pragma mark UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    WEPhotoALAssets *photoALAsset = self.photoALAssets[self.photosCount - indexPath.row];
    photoALAsset.selected = !photoALAsset.isSelected;
    
    if (photoALAsset.isSelected) {
        [self.selectedPhotos addObject:photoALAsset];
        if (self.selectedPhotos.count > self.maxCount) {
            [self.selectedPhotos removeLastObject];
            photoALAsset.selected = NO;
        }
    } else {
        [self.selectedPhotos removeObject:photoALAsset];
    }
    
    NSString *photoCount = [NSString stringWithFormat:@"已经选择 %lu 张照片",(unsigned long)self.self.selectedPhotos.count];
    _photoCountLab.text = self.selectedPhotos.count == 0 ?@"请选择照片":photoCount;

    [collectionView reloadItemsAtIndexPaths:@[indexPath]];
}


#pragma mark - completeAction
- (void)completeAction {
    
    if (self.selectedPhotos.count == 0) return;
    
    __weak typeof (self) selfVc = self;
    [[[NSOperationQueue alloc]init] addOperationWithBlock:^{
        for (WEPhotoALAssets *photoALAsset in self.selectedPhotos) {
            if (WEImagePicker_System_iOS8) {
                [selfVc imageWithAsset:photoALAsset.photoAsset completion:^(UIImage *image) {
                    [selfVc.imageArray addObject:image];
                }];
            }else {
                ALAsset *sset = photoALAsset.photoALAsset;
                ALAssetRepresentation *assetRepresentation = [sset defaultRepresentation];
                CGFloat imageScale = [assetRepresentation scale];
                UIImageOrientation imageOrientation = (UIImageOrientation)[assetRepresentation orientation];
                UIImage *originalImage = [UIImage imageWithCGImage:sset.defaultRepresentation.fullScreenImage scale:imageScale orientation:imageOrientation];
                [selfVc.imageArray addObject:originalImage];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (selfVc.block) {
                [selfVc dismissViewControllerAnimated:YES completion:^{
                    selfVc.block(selfVc.imageArray);
                    selfVc.selectedPhotos = nil;
                    selfVc.imageArray = nil;
                }];
            }else {
                selfVc.selectedPhotos = nil;
                selfVc.imageArray = nil;
            }
        });
    }];

}

#pragma mark - obj getters && setters

- (NSMutableArray *)imageArray {
    if (!_imageArray) {
        _imageArray = [NSMutableArray array];
    }
    return _imageArray;
}

- (UIButton *)completeBtn
{
    if (!_completeBtn) {
        _completeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_completeBtn setTitle:@"完成" forState:UIControlStateNormal];
        _completeBtn.frame = CGRectMake(WEScreenWidth - 65, 9, 60, 30);
        _completeBtn.titleLabel.font = [UIFont systemFontOfSize:16];
        _completeBtn.backgroundColor = [UIColor clearColor];
        [_completeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_completeBtn addTarget:self action:@selector(completeAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _completeBtn;
}

- (UILabel *)photoCountLab
{
    if (!_photoCountLab) {
        _photoCountLab = [[UILabel alloc]initWithFrame:CGRectMake(15, 9, 200, 30)];
        _photoCountLab.textColor =[UIColor whiteColor];
        _photoCountLab.font = [UIFont systemFontOfSize:16];
        NSString *photoCount = [NSString stringWithFormat:@"已经选择 %lu 张照片",(unsigned long)self.self.selectedPhotos.count];
        _photoCountLab.text = self.selectedPhotos.count == 0 ?@"请选择照片":photoCount;
    }
    return _photoCountLab;
}

@end


@implementation WEPhotoCell

- (void)setPhotoALAsset:(WEPhotoALAssets *)photoALAsset {
    
    _photoALAsset = photoALAsset;
    
    if (WEImagePicker_System_iOS8) {
        //iOS8以上使用PHAsset
        [self imageWithAsset:photoALAsset.photoAsset completion:^(UIImage *image) {
            self.iconView.image = image;
        }];
    } else {
        //iOS8以下使用ALAsset
        ALAsset *alasset = photoALAsset.photoALAsset;
        if ([[alasset valueForProperty:@"ALAssetPropertyType"] isEqualToString:ALAssetTypePhoto]) {
            self.iconView.image = [UIImage imageWithCGImage:alasset.thumbnail];
        }
    }
    
    self.selectedView.hidden = !photoALAsset.isSelected;
    self.selectedBtn.hidden = !photoALAsset.isSelected;
}

// 从PHAsset中获取image
- (void)imageWithAsset:(PHAsset *)asset completion:(WEImagePicker_imageBlock)completion {
    
    PHImageRequestOptions *imageOptions = [[PHImageRequestOptions alloc] init];
    imageOptions.synchronous = YES;
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(self.bounds.size.width * 2, self.bounds.size.height * 2) contentMode:PHImageContentModeAspectFill options:imageOptions resultHandler:^(UIImage *result, NSDictionary *info) {
        completion(result);
    }];
}

#pragma mark - view getters

- (UIImageView *)iconView {
    if (!_iconView) {
        UIImageView *iconView = [[UIImageView alloc]initWithFrame:self.bounds];
        iconView.contentMode = UIViewContentModeScaleAspectFill;
        iconView.clipsToBounds = YES;
        [self.contentView addSubview:iconView];
        _iconView = iconView;
    }
    return _iconView;
}

- (UIView *)selectedView {
    if (!_selectedView) {
        UIView *selectedView = [[UIView alloc]initWithFrame:self.bounds];
        selectedView.backgroundColor = [UIColor whiteColor];
        selectedView.alpha = .0f;
        [self.iconView addSubview:selectedView];
        _selectedView = selectedView;
    }
    return _selectedView;
}

- (UIButton *)selectedBtn {
    if (!_selectedBtn) {
        UIButton *selectedBtn = [[UIButton alloc]init];
        selectedBtn.userInteractionEnabled = NO;
        NSString *imageFile = [[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:@"WEImagePicker.bundle/sel@2x.png"];
        [selectedBtn setImage:[UIImage imageWithContentsOfFile:imageFile] forState:UIControlStateNormal];
        CGFloat margin = 5;
        selectedBtn.frame = CGRectMake(0, 0, selectedBtn.currentImage.size.width, selectedBtn.currentImage.size.height);
        CGFloat selectedBtnX = CGRectGetWidth(_iconView.frame) - CGRectGetWidth(selectedBtn.frame) - margin;
        CGFloat selectedBtnY = CGRectGetHeight(_iconView.frame) - CGRectGetHeight(selectedBtn.frame) - margin;
        selectedBtn.frame = CGRectMake(selectedBtnX, selectedBtnY, selectedBtn.currentImage.size.width, selectedBtn.currentImage.size.height);
        [self.iconView addSubview:selectedBtn];
        _selectedBtn = selectedBtn;
    }
    return _selectedBtn;
}

@end
